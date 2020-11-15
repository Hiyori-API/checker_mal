defmodule CheckerMal.Core.Scheduler do
  @moduledoc """
  Periodically checks the config/postgres db
  Based on when those page ranges were last run,
  decides when to request how many pages from MAL
  """

  @type_keys [:anime, :manga]

  import Ecto.Query, warn: false
  alias CheckerMal.Core.Scheduler.Config
  alias CheckerMal.PageState
  alias CheckerMal.PageState.PageStateData

  # TODO: implement GenServer loop
  # TODO: implement handle_cast which receives a page number from index
  # TODO: implement check for expired

  def read_state() do
    state_data =
      PageState.list_pagestate()
      |> Enum.map(fn %PageStateData{
                       period: period,
                       timeframe: timeframe,
                       type: type,
                       updated_at: last_ran
                     } ->
        {type, {timeframe, period, last_ran}}
      end)
      |> Enum.group_by(fn {type, _} -> type end, fn {_, data} -> data end)

    @type_keys
    |> Enum.map(fn type ->
      stype = Config.stringify_key(type)
      key_list = state_data[stype]

      valid_state =
        Config.read_config(type)
        |> Map.to_list()
        |> Enum.map(fn {timeframe, period} ->
          Enum.find(key_list, :error_no_state_match, fn {ktimeframe, kperiod, _last_ran} ->
            kperiod == period and ktimeframe == timeframe
          end)
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
