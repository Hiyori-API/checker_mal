defmodule CheckerMal.Core.Unapproved do
  alias CheckerMal.Core.Unapproved.Utils
  alias CheckerMal.Core.Unapproved.Parser
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    {:ok, init_state}
  end

  # reminder that this takes ages to request/parser, so timeouts should be generous
  def handle_cast(:maybe_update, state) do
    state = run_if_expired(state)
    {:noreply, state}
  end

  def handle_cast(:force_update, state) do
    {:noreply, run_update(state)}
  end

  # TODO: add functions which accept the current approved cache and return unapproved IDs
  def handle_call({:get_all_anime}, _from, state) do
    state = run_if_expired(state)
    {:reply, Map.get(state, "all_anime"), state}
  end

  def handle_call({:get_all_manga}, _from, state) do
    state = run_if_expired(state)
    {:reply, Map.get(state, "all_manga"), state}
  end

  defp run_if_expired(state) do
    if Utils.has_expired?(state) or not Utils.has_data?(state) do
      Logger.info("Running update for unapproved cache...")
      run_update(state)
    else
      Logger.debug("Unapproved cache is already up to date")
      state
    end
  end

  defp run_update(state) do
    Map.merge(state, Parser.request())
    |> Map.merge(%{"at" => DateTime.utc_now()})
  end
end

defmodule CheckerMal.Core.Unapproved.Utils do
  def has_data?(state) do
    min =
      [Map.get(state, "all_anime", []), Map.get(state, "all_manga", [])]
      |> Enum.map(&length/1)
      |> Enum.min()

    min > 0
  end

  def has_expired?(state) do
    now = DateTime.utc_now()

    expire_seconds =
      div(Application.get_env(:checker_mal, :unapproved_page_expire_time, :timer.hours(3)), 1000)

    cond do
      not Map.has_key?(state, "at") ->
        true

      DateTime.diff(now, Map.get(state, "at", now)) > expire_seconds ->
        true

      true ->
        false
    end
  end
end

defmodule CheckerMal.Core.Unapproved.Wrapper do
  @moduledoc """
  Exposes the Genserver.call with long timeouts as functions
  """

  defp get_handler(genserver_atom) when is_atom(genserver_atom), do: get_handler({genserver_atom})

  defp get_handler(genserver_data),
    do: GenServer.call(CheckerMal.Core.Unapproved, genserver_data, :timer.minutes(10))

  def get_all_anime(), do: get_handler(:get_all_anime)
  def get_all_manga(), do: get_handler(:get_all_manga)
  # hd works here since IDs are reverse sorted after being parsed (in table_to_ids)
  def get_last_anime_id(), do: get_handler(:get_all_anime) |> hd()
  def get_last_manga_id(), do: get_handler(:get_all_manga) |> hd()
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
        %{"all_anime" => [], "all_manga" => []}
    end
  end

  def parse_unapproved_page(html_response) do
    {:ok, document} = Floki.parse_document(html_response)
    [anime, manga] = Floki.find(document, "div.normal_header + table")

    %{
      "all_anime" => table_to_ids(anime),
      "all_manga" => table_to_ids(manga)
    }
  end

  defp table_to_ids(type_table) do
    # the 'a' elements' text is the ID for this entry
    Floki.find(type_table, "a")
    |> Enum.map(fn {_tag, _attrs, [id_str]} -> String.to_integer(id_str) end)
    |> Utils.reverse_sort()
  end
end
