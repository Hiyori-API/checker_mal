defmodule CheckerMal.UnapprovedHtml.EntryCache do
  alias CheckerMal.MALEntry
  alias CheckerMal.MALEntry.MALEntryData

  use GenServer
  require Logger

  @loop_period :timer.seconds(Application.get_env(:checker_mal, :mal_wait_time, 15))

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    schedule_check()

    state =
      Map.merge(init_state, %{
        :cached => read_cache_from_db(),
        :uncached => [],
        :client => JikanEx.client()
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
    # if theres things left to cache
    if not Enum.empty?(state[:uncached]) do
      [{type, id} | rest_uncached] = state[:uncached]

      cache =
        case request_data(state[:client], type, id) do
          {:ok, resp} ->
            {name, etype, nsfw} = save_resp_to_db(type, id, resp)
            Map.put(state[:cached], {type, id}, {name, etype, nsfw})

          {:error, _err} ->
            Logger.warn("EntryCache: Could not cache #{type} #{id}, ignoring...")
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
    name = resp["title"]
    etype = resp["type"]
    nsfw = 12 in Enum.map(resp["genres"], fn %{"mal_id" => genre_id} -> genre_id end)

    {:ok, _} =
      MALEntry.create_mal_entry_data(%{
        :entrytype => etype,
        :mal_id => id,
        :name => name,
        :nsfw => nsfw,
        :type => type
      })

    {name, etype, nsfw}
  end

  defp request_data(jikan_client, type, id) when is_bitstring(type),
    do: request_data(jikan_client, string_to_req_atom(type), id)

  defp request_data(jikan_client, type, id) when is_atom(type),
    do: apply(JikanEx.Request, type, [jikan_client, id])

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

  defp string_to_req_atom("anime"), do: :anime
  defp string_to_req_atom("manga"), do: :manga

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
