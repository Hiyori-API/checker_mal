defmodule CheckerMal.Core.Scheduler do
  @moduledoc """
  Periodically checks the config/postgres db
  Based on when those page ranges were last run,
  decides when to request how many pages from MAL

  all requests to update page ranges should come through
  here, since this implements a locking mechanism to
  prevent muliple jobs from running concurrently

  State includes:
    anime: [anime page data (from db)]
    manga: [manga... (same as anime)]
    lock: bool  # whether or not something is requesting currently

  locked is set in maintenance if some task is starting, else
  (for future usage), if a request to check a page was received
  from somewhere else

  finished_requesting is called by the called process, to mark
  how many pages were checked

  any other requests made while there this is locked will wait in
  an aquire. up to the callee on how to handle retrying trying to
  do that in a handle_call and GenServer timeout occurs
  """

  import Ecto.Query, warn: false
  alias CheckerMal.Core.Utils
  alias CheckerMal.Core.Scheduler.Config
  alias CheckerMal.Core.Index
  alias CheckerMal.PageState
  alias CheckerMal.PageState.PageStateData

  require Logger
  use GenServer

  @type_keys [:anime, :manga]
  @loop_period Application.get_env(:checker_mal, :scheduler_loop_time, :timer.minutes(5))

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    state = Map.merge(init_state, %{lock: false})
    # create any missing page ranges, if needed
    init_db()
    # so this doesn't stop initial startup process
    schedule_check(:timer.seconds(10))
    {:ok, Map.merge(state, read_state())}
  end

  def schedule_check(in_ms \\ @loop_period),
    do: Process.send_after(Process.whereis(CheckerMal.Core.Scheduler), :check, in_ms)

  def handle_info(:check, state), do: {:noreply, maintenance(state)}

  @doc """
  Checks if any of the page ranges have expired, makes requests by spawning processes if any have
  """
  def maintenance(state) do
    Logger.debug("ID Checker: Checking if any page ranges have expired...")
    state = Map.merge(state, read_state())
    expired_ranges = check_expired(state)
    # this doesn't schedule check here, since if a task takes more than @loop_period
    # that would mean lots of :check requests would attempt to aquire the lock
    # instead, that schedule is done in finished_requesting
    #
    # if we can acquire, this means theres nothing else running
    state =
      if not state[:lock] do
        # try to update pages
        cast_pages(state, expired_ranges)
      else
        state
      end

    # reschedule
    schedule_check()
    state
  end

  defp cast_pages(state, expired_ranges) do
    if length(expired_ranges) > 0 do
      # I think this should be fine, this is only going to care
      # about the SFW request sending the page range back to finished_requesting
      # otherwise, there are 11x as more SFW entries anyways, so NSFW should
      # always be checked well enough
      #
      # process one job
      {type, timeframe} = expired_ranges |> hd()
      # spawn a process and run update there
      # aquire the lock in the child process, so multiple don't run concurrently
      # and this doesn't block the genserver waiting to aquire the lock
      # link with child process, this genserver crashes/restarts if that crashes
      {:ok, _task} =
        Task.start_link(fn ->
          Index.request(
            type,
            timeframe,
            fn page_count, stop_strategy, type ->
              GenServer.call(
                CheckerMal.Core.Scheduler,
                {:finished_requesting, page_count, stop_strategy, type},
                :timer.minutes(1)
              )
            end
          )
        end)

      %{state | lock: true}
    else
      state
    end
  end

  @doc """
  Checks if any page ranges have expired. If any have, for both @type_keys
  returns the page which has the highest page range value, that way we're
  not duplicating work

  Returns 0, 1, or 2 jobs, if any have expired
  """
  def check_expired(state, now \\ NaiveDateTime.utc_now()) do
    @type_keys
    |> Enum.map(fn type ->
      expired_for_type =
        state[type]
        |> Enum.filter(fn {_timeframe, period, last_run} ->
          NaiveDateTime.diff(now, last_run) > period
        end)
        |> Enum.map(fn {timeframe, _, _} -> timeframe end)
        |> Config.sort_config(type)

      if length(expired_for_type) > 0 do
        {type, Utils.last(expired_for_type)}
      else
        {type, nil}
      end
    end)
    |> Enum.reject(fn {_, dat} -> is_nil(dat) end)
  end

  def read_state() do
    state_data =
      PageState.list_pagestate()
      |> Enum.map(fn %PageStateData{
                       timeframe: timeframe,
                       type: type,
                       updated_at: last_ran
                     } ->
        {type, {timeframe, last_ran}}
      end)
      |> Enum.group_by(fn {type, _} -> type end, fn {_, data} -> data end)

    @type_keys
    |> Enum.map(fn type ->
      stype = Config.stringify_key(type)
      key_list = state_data[stype]

      # TODO: remove timeframe from db? its always pulled from the configuration, and
      # it only causes more trouble having to update it in the database
      valid_state =
        Config.read_config(type)
        |> Map.to_list()
        |> Enum.map(fn {timeframe, period} ->
          {_, last_ran} =
            Enum.find(key_list, :error_no_state_match, fn {ktimeframe, _last_ran} ->
              ktimeframe == timeframe
            end)

          {timeframe, period, last_ran}
        end)

      {type, valid_state}
    end)
    |> Enum.into(Map.new())
  end

  @doc """
  Initializes the data in the database for the each page ranges and type if it doesn't already exist
  Called when the GenServer starts, to make sure each state item exists in the database
  """
  def init_db() do
    @type_keys
    |> Enum.each(fn type ->
      Config.read_config(type)
      |> Map.to_list()
      |> Enum.map(fn {timeframe, period} ->
        PageState.insert_pagestate_if_doesnt_exist(timeframe, period, type)
      end)
    end)
  end

  @doc """
  After something finishes requesting a certain number of pages,
  it sends either the page count or the atom for which it requested,
  a particular page range for back to this GenServer

  Mark any items which are that or less than this page range as 'done' now,
  if something extended past what it should have checked
  """
  def finished_requesting(page_count, stop_strategy, type) when is_integer(page_count) do
    Config.find_smaller_in_range(page_count, stop_strategy, type)
    |> Enum.map(fn timeframe ->
      update_query =
        from pd in PageStateData,
          where: pd.type == ^Config.stringify_key(type) and pd.timeframe == ^timeframe,
          update: [set: [updated_at: ^NaiveDateTime.utc_now()]]

      CheckerMal.Repo.update_all(update_query, [])
    end)
  end

  def handle_call({:finished_requesting, page_count, stop_strategy, type}, _from, state) do
    {:reply, finished_requesting(page_count, stop_strategy, type), %{state | lock: false}}
  end
end

defmodule CheckerMal.Core.Scheduler.Config do
  @moduledoc """
  Handle sorting the read configuration, so when we proces larger page ranges
  we can overwrite smaller page ranges as well
  """

  alias CheckerMal.Core.Utils

  @anime_pages :anime_pages
  @manga_pages :manga_pages

  @doc """
  iex> CheckerMal.Core.Scheduler.Config.page_atom(:anime)
  :anime_pages
  iex> CheckerMal.Core.Scheduler.Config.page_atom(:manga)
  :manga_pages
  """
  def page_atom(type) do
    case type do
      :anime -> @anime_pages
      :manga -> @manga_pages
    end
  end

  # reads the information from config/pages.exs into
  # something that can be compared into when items were last
  # updated from the database
  def read_config(type) do
    conf_atom = page_atom(type)

    conf = Application.get_env(:checker_mal, conf_atom)

    if is_nil(conf) do
      raise "Could not get configuration for #{:checker_mal} for #{conf_atom}"
    end

    stringify_config(conf)
  end

  @doc """
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(3, :page_range, :anime)
  ["3"]
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(10, :page_range, :anime)
  ["3", "8"]
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(25, :page_range, :anime)
  ["3", "8", "20"]
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(84, :page_range, :anime)
  ["3", "8", "20", "40"]
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(200, :unapproved, :anime)
  ["3", "8", "20", "40", "unapproved"]
  iex> CheckerMal.Core.Scheduler.Config.find_smaller_in_range(300, :infinite, :manga)
  ["3", "8", "20", "40", "unapproved", "infinite"]
  """
  def find_smaller_in_range(pcount, stop_strategy, type),
    do: find_smaller_in_range(pcount, stop_strategy, type, page_order(type))

  def find_smaller_in_range(pcount, :page_range, _type, ranges) do
    ranges
    |> Enum.filter(fn p -> Integer.parse(p) != :error end)
    |> Enum.map(&String.to_integer/1)
    |> Enum.filter(fn p -> pcount >= p end)
    |> Enum.map(&Integer.to_string/1)
  end

  # mark everything but :infinite as done
  def find_smaller_in_range(_pcount, :unapproved, type, ranges) do
    inf = Utils.last(page_order(type))
    Enum.filter(ranges, fn p -> p != inf end)
  end

  # mark everything done
  def find_smaller_in_range(_pcount, :infinite, type, _ranges), do: page_order(type)

  # for other strategies (:one, perhaps :testing), nothing should be saved to the db, so return nothing
  def find_smaller_in_range(_pcount, _stop_strategy, _type, _ranges), do: []

  @doc """
  iex> CheckerMal.Core.Scheduler.Config.sort_config(Enum.shuffle(CheckerMal.Core.Scheduler.Config.page_order(:anime)), :anime)
  CheckerMal.Core.Scheduler.Config.page_order(:anime)
  """
  def sort_config(enum, type) do
    pageord = page_order(type)
    Enum.sort(enum, fn a, b -> sort_key(a, b, pageord) == a end)
  end

  # returns the smaller key, according to the where it appears in the list given
  # used in sort_config
  def sort_key(a, b, []), do: raise("Could not sort #{a} with #{b} given page order")

  def sort_key(a, b, [cur | rest]) do
    cond do
      cur == a -> a
      cur == b -> b
      true -> sort_key(a, b, rest)
    end
  end

  defp stringify_config(conf), do: stringify_config(conf, %{})
  defp stringify_config([], map), do: map

  defp stringify_config([{page_count, period} | rest], map),
    do: stringify_config(rest, Map.put(map, stringify_key(page_count), period))

  def page_order(type) do
    Application.get_env(:checker_mal, page_atom(type))
    |> Enum.map(fn {key, _} -> stringify_key(key) end)
  end

  def stringify_key(k) when is_atom(k), do: Atom.to_string(k)
  def stringify_key(n) when is_number(n), do: Integer.to_string(n)
end
