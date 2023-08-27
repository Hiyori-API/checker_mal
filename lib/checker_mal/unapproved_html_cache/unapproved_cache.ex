defmodule CheckerMal.UnapprovedHtml.Cache do
  alias CheckerMal.Core.Unapproved.Wrapper
  alias CheckerMal.Core.Utils

  use GenServer
  require Logger

  @unapproved_check_time Application.compile_env(
                           :checker_mal,
                           :unapproved_check_time,
                           :timer.minutes(5)
                         )

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    schedule_check(:timer.seconds(1))
    {:ok, init_state}
  end

  def schedule_check(in_ms \\ @unapproved_check_time),
    do: Process.send_after(self(), :check_ids, in_ms)

  def handle_info(:check_ids, state) do
    schedule_check()
    Logger.debug("UnapprovedHtml: updating id cache...")
    state = update_id_cache(state)
    {:noreply, state}
  end

  def handle_call(:anime, _from, state), do: {:reply, compute_unapproved(:anime, state), state}

  defp get_map_keys(:anime), do: {"approved_anime_ids", "unapproved_anime_ids"}

  defp compute_unapproved("anime", state), do: compute_unapproved(:anime, state)

  defp compute_unapproved(type, state) when is_atom(type) do
    {ak, uk} = get_map_keys(type)
    MapSet.difference(state[uk], state[ak]) |> MapSet.to_list() |> Utils.reverse_sort()
  end

  def update_id_cache(state) do
    # wait till unapproved GenServer has parsed results
    Wrapper.wait_till_parsed()

    state =
      Map.merge(state, %{
        "unapproved_anime_ids" => Wrapper.get_all_anime() |> MapSet.new()
      })

    state = Map.merge(state, read_valid_ids())

    # cast requests unapproved entries off to entry cache genserver, to save type/name
    ["anime"]
    |> Enum.each(fn type ->
      compute_unapproved(type, state)
      |> Enum.each(fn id ->
        GenServer.cast(CheckerMal.UnapprovedHtml.EntryCache, {:cache_entry, type, id})
      end)
    end)

    state
  end

  defp read_valid_ids() do
    %{
      "approved_anime_ids" => read_valid_id_for(:anime)
    }
  end

  # type should be :anime or :manga (though manga is disabled)
  defp read_valid_id_for(type) do
    sfw_ids = CheckerMal.Backend.EntryPoint.read(type, :sfw)
    nsfw_ids = CheckerMal.Backend.EntryPoint.read(type, :nsfw)
    Enum.concat(sfw_ids, nsfw_ids) |> MapSet.new()
  end
end
