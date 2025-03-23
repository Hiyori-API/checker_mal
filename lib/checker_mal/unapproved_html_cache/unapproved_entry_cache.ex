defmodule CheckerMal.UnapprovedHtml.EntryCache do
  alias CheckerMal.MALEntry
  alias CheckerMal.MALEntry.MALEntryData

  use GenServer
  require Logger

  @loop_period :timer.seconds(Application.compile_env(:checker_mal, :entrycache_wait, 2))
  @api_key Application.compile_env(:checker_mal, :mal_api_key)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    schedule_check()

    if is_nil(@api_key) do
      raise "No API key set, set the MAL_CLIENTID environment variable"
    end

    state =
      Map.merge(init_state, %{
        :cached => read_cache_from_db(),
        :uncached => []
      })

    {:ok, state}
  end

  def read_cache_from_db() do
    MALEntry.list_malentry()
    |> Enum.map(fn %MALEntryData{
                     name: name,
                     nsfw: nsfw,
                     type: type,
                     mal_id: mal_id,
                     entrytype: etype
                   } ->
      {{type, mal_id}, {name, etype, nsfw}}
    end)
    |> Enum.into(Map.new())
  end

  def schedule_check(in_ms \\ @loop_period),
    do: Process.send_after(self(), :check_uncached, in_ms)

  def handle_info(:check_uncached, state) do
    schedule_check()
    state = check_uncached(state)
    {:noreply, state}
  end

  def handle_cast({:cache_entry, type, id}, state) when is_integer(id) and is_bitstring(type) do
    state = Map.put(state, :uncached, [{type, id} | state[:uncached]])
    {:noreply, state}
  end

  defp check_uncached(state) do
    # remove any items that are already cached
    state = remove_uncached_from_head(state)
    # if there's things left to cache
    if not Enum.empty?(state[:uncached]) do
      [{type, id} | rest_uncached] = state[:uncached]

      cache =
        case request_data(type, id) do
          {:ok, resp} ->
            case resp.status_code do
              200 ->
                resp_json = Jason.decode!(resp.body)
                {name, etype, nsfw} = save_resp_to_db(type, id, resp_json)
                Map.put(state[:cached], {type, id}, {name, etype, nsfw})

              _ ->
                Logger.warning(
                  "EntryCache: Could not cache #{type} #{id}, failed with #{resp.status_code} ignoring..."
                )

                state[:cached]
            end

          {:error, _err} ->
            Logger.warning("EntryCache: Could not cache #{type} #{id}, ignoring...")
            state[:cached]
        end

      state
      |> Map.put(:uncached, rest_uncached)
      |> Map.put(:cached, cache)
    else
      state
    end
  end

  defp save_resp_to_db(type, id, resp) when is_bitstring(type) do
    name = resp["title"] || "Unknown"
    etype = resp["media_type"] || "Unknown"
    genre_ids = Enum.map(resp["genres"] || [], fn %{"id" => genre_id} -> genre_id end)
    nsfw = 12 in genre_ids

    {:ok, _} =
      MALEntry.create_mal_entry_data(%{
        :entrytype => etype,
        :mal_id => id,
        :name => name,
        :nsfw => nsfw,
        :type => type
      })

    Logger.info("Saved #{name} (#{etype}) #{nsfw}")

    {name, etype, nsfw}
  end

  defp request_data(type, id) when is_bitstring(type) do
    url =
      "https://api.myanimelist.net/v2/#{type}/#{id}?nsfw=true&fields=id,title,nsfw,genres,media_type"

    HTTPoison.get(url, [{"X-MAL-CLIENT-ID", @api_key}])
  end

  defp request_data(:anime, id), do: request_data("anime", id)
  defp request_data(:manga, id), do: request_data("manga", id)

  defp remove_uncached_from_head(state) do
    Map.put(
      state,
      :uncached,
      Enum.drop_while(state[:uncached], &in_cache?(state, &1))
    )
  end

  defp in_cache?(state, {type, id}) when is_bitstring(type) do
    Map.has_key?(state[:cached], {type, id})
  end

  def handle_call({:get_info, type, ids}, _from, state)
      when is_list(ids) and is_bitstring(type) do
    info =
      ids
      |> Enum.map(fn id ->
        {id, Map.get(state[:cached], {type, id})}
      end)
      |> Enum.reject(fn {_, data} -> is_nil(data) end)
      |> Enum.into(%{})

    {:reply, info, state}
  end
end
