defmodule CheckerMalWeb.UnapprovedController do
  use CheckerMalWeb, :controller
  require Logger

  @html_basepath Application.get_env(:checker_mal, :unapproved_html_basepath, "/mal_unapproved")

  @error_msg "Page is currently being updated, this page will automatically refresh when its done..."

  def get_data(type) when is_atom(type) do
    # last_updated_at returns :error when server is still booting
    case GenServer.call(CheckerMal.Core.Unapproved, :last_updated_at) do
      {:ok, last_updated_naive} ->
        ids =
          try do
            GenServer.call(CheckerMal.UnapprovedHtml.Cache, type)
          catch
            :exit, {:timeout, _err} ->
              []
          end

        %{
          :since_update_mins =>
            div(NaiveDateTime.diff(NaiveDateTime.utc_now(), last_updated_naive), 60),
          :ids => ids
        }

      {:error, :uninitialized} ->
        %{ids: [], refresh_equiv: true}
    end
  end

  def fetch_metadata(stype, ids) when is_bitstring(stype) and is_list(ids) do
    GenServer.call(
      CheckerMal.UnapprovedHtml.EntryCache,
      {:get_info, stype, ids},
      :timer.seconds(10)
    )
    |> Map.to_list()
    |> Enum.map(fn {id, {name, etype, nsfw}} ->
      {id,
       %{
         :name => name,
         :type => etype,
         :nsfw => nsfw
       }}
    end)
    |> Enum.into(Map.new())
  end

  defp data_controller(type, conn) do
    stype = Atom.to_string(type)

    data = get_data(type)

    # flash error if page is initializing/updating
    conn =
      cond do
        Enum.empty?(data[:ids]) ->
          conn
          |> put_flash(:error, @error_msg)

        true ->
          conn
      end

    # get entry info (name/type/nsfw)
    entryinfo = fetch_metadata(stype, data[:ids])

    # map so that its easier to use in eex

    data =
      Map.put(data, :info, entryinfo)
      |> Map.put(
        :title,
        "Unapproved MAL Entries - #{stype |> String.capitalize()}"
      )
      |> Map.put(:basepath, @html_basepath)
      |> Map.put(:type, stype)

    {conn, data}
  end

  def controller(conn, type) when is_atom(type) do
    {conn, data} = data_controller(type, conn)
    render(conn, "unapproved.html", data: data)
  end

  def anime(conn, _params), do: controller(conn, :anime)
  def manga(conn, _params), do: controller(conn, :manga)
end
