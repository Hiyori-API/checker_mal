defmodule CheckerMal.Core.Unapproved do
  @moduledoc """
  This caches unapproved anime and manga IDs on myanimelist.

  In particular, it caches *all* IDs, approved
  and unapproved. In order to compute which ones
  are unapproved, take the set difference with
  the source from CheckerMal.Backend.EntryPoint.read
  """

  alias CheckerMal.Core.Unapproved.Utils
  alias CheckerMal.Core.Unapproved.Parser
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    state = Map.merge(default_state(), init_state)
    {:ok, state}
  end

  # includes an 'is_updating' field since the request/parsing
  # can take up to a minute
  # else, the GenServer is blocked and timeouts occur while that
  # is happening
  defp default_state(), do: %{"all_anime" => [], "all_manga" => [], "is_updating" => false}

  # if the state has expired, update in the background
  defp update_async(state) do
    if not has_valid_data?(state) do
      # dont run if already updating
      if not state["is_updating"] do
        spawn_link(fn ->
          GenServer.cast(CheckerMal.Core.Unapproved, {:update_results, Parser.request()})
        end)
      end

      state |> Map.put("is_updating", true)
    else
      state
    end
  end

  # doesnt use state since the results from the scraper and
  # keys the map is merged with accounts for all of the state
  def handle_cast({:update_results, scraper_resp}, _state) do
    # marks the time and is_updating keys when unapproved page is finished updating
    {:noreply,
     scraper_resp
     |> Map.merge(%{
       "at" => NaiveDateTime.utc_now(),
       "is_updating" => false
     })}
  end

  def handle_call(:get_all_anime, _from, state) do
    state = update_async(state)
    {:reply, Map.get(state, "all_anime"), state}
  end

  def handle_call(:get_all_manga, _from, state) do
    state = update_async(state)
    {:reply, Map.get(state, "all_manga"), state}
  end

  def handle_call(:last_updated_at, _from, state) do
    resp =
      if Map.has_key?(state, "at") do
        {:ok, state["at"]}
      else
        {:error, :uninitialized}
      end

    {:reply, resp, state}
  end

  def handle_call(:has_valid_data?, _from, state),
    do: {:reply, has_valid_data?(state), state}

  def handle_call(:is_updating, _from, state),
    do: {:reply, Map.get(state, "is_updating", true), state}

  defp has_valid_data?(state), do: Utils.has_data?(state) and not Utils.has_expired?(state)
end

defmodule CheckerMal.Core.Unapproved.Utils do
  def has_data?(state) do
    min =
      [Map.get(state, "all_anime", []), Map.get(state, "all_manga", [])]
      |> Enum.map(&length/1)
      |> Enum.min()

    min > 0
  end

  @page_expire_time Application.compile_env(
                      :checker_mal,
                      :unapproved_page_expire_time,
                      :timer.hours(3)
                    )

  def has_expired?(state) do
    now = NaiveDateTime.utc_now()

    expire_seconds = div(@page_expire_time, 1000)

    cond do
      not Map.has_key?(state, "at") ->
        true

      NaiveDateTime.diff(now, Map.get(state, "at", now)) > expire_seconds ->
        true

      true ->
        false
    end
  end
end

defmodule CheckerMal.Core.Unapproved.Wrapper do
  @moduledoc """
  Exposes the Genserver.call anime/manga endpoints

  the wait_till_parsed function waits until get_all_anime
  returns some results, can be used in other modules
  to wait in a sleep loop till the GenServer above
  is initialized
  """

  defp get_handler(genserver_atom) when is_atom(genserver_atom),
    do: GenServer.call(CheckerMal.Core.Unapproved, genserver_atom)

  # primarily used on the webpage
  @spec get_all_anime() :: [integer()]
  def get_all_anime(), do: get_handler(:get_all_anime)
  @spec get_all_manga() :: [integer()]
  def get_all_manga(), do: get_handler(:get_all_manga)

  # primarly used in the indexer
  # hd works here since IDs are reverse sorted after being parsed (in table_to_ids)
  @spec get_last_anime_id() :: integer()
  def get_last_anime_id(), do: get_handler(:get_all_anime) |> hd()
  @spec get_last_manga_id() :: integer()
  def get_last_manga_id(), do: get_handler(:get_all_manga) |> hd()

  # this can be called from other modules, to wait in a sleep loop
  # after it returns, other modules can request the get_all_anime
  # and get_all_manga and know they return data
  def wait_till_parsed(), do: wait_till_parsed(fn -> get_all_anime() end)

  def wait_till_parsed(request_func) when is_function(request_func),
    do: wait_till_parsed([], request_func)

  # Wrapper.get_all_anime() requests
  # asyncronously, so if it has expired, the next
  # time @unapproved_check_time has elapsed, the items will
  # have updated
  # If get_all_anime returns an empty list, the application
  # probably just started, so we should wait here syncronously
  # so we have to up to date IDs
  def wait_till_parsed([], request_func) when is_function(request_func) do
    :timer.sleep(50)
    wait_till_parsed(request_func.(), request_func)
  end

  # base case
  def wait_till_parsed(results, _request_func) when is_list(results) and length(results) > 0,
    do: results
end

defmodule CheckerMal.Core.Unapproved.Parser do
  alias CheckerMal.Core.Scraper
  alias CheckerMal.Core.Utils
  require Logger

  @relation_id_page "https://myanimelist.net/info.php?search=%25%25%25&go=relationids&divname=relationGen1"

  def request() do
    case Scraper.rated_http_get(@relation_id_page) do
      {:ok, html_response} ->
        parse_unapproved_page(html_response)

      {:error, err} ->
        Logger.error(err)
        %{}
    end
  end

  @spec parse_unapproved_page(String.t()) :: %{}
  def parse_unapproved_page(html_response) do
    {:ok, document} = Floki.parse_document(html_response)
    [anime, manga] = Floki.find(document, "div.normal_header + table")

    %{
      "all_anime" => table_to_ids(anime),
      "all_manga" => table_to_ids(manga)
    }
  end

  @spec table_to_ids(Floki.html_tag()) :: [integer()]
  defp table_to_ids({"table", _attrs, children} = _type_table) when is_list(children) do
    # the 'a' elements' text is the ID for this entry
    Floki.find(children, "a")
    |> Enum.map(fn node ->
      case node do
        {_tag, _attrs, [id]} when is_binary(id) ->
          id |> String.to_integer()

        _ ->
          Logger.error("Could not parse node #{inspect(node)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Utils.reverse_sort()
  end

  defp table_to_ids(data) do
    raise "Could not parse table, expected a Floki.html_tag(), got #{inspect(data)}"
  end
end
