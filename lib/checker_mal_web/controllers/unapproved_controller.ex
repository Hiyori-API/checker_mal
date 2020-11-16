defmodule CheckerMalWeb.UnapprovedController do
  use CheckerMalWeb, :controller
  require Logger

  defp stringify_type(:anime), do: %{type: "anime"}
  defp stringify_type(:manga), do: %{type: "manga"}

  defp get_data(type, conn) do
    last_updated =
      try do
        GenServer.call(CheckerMal.Core.Unapproved, :last_updated_at, :timer.seconds(3))
      catch
        :exit, {:timeout, _err} ->
          Logger.warning("GenServer timeout when trying to fetch when last updated")
          {:error, :genserver_timeout}
      end

    data =
      case last_updated do
        {:ok, last_updated_naive} ->
          # if we recieved this, the GenServer probably wouldn't be blocked by some other request
          ids =
            try do
              GenServer.call(CheckerMal.UnapprovedHtml.Cache, type)
            catch
              :exit, {:timeout, _err} ->
                []
            end

          stringify_type(type)
          |> Map.merge(%{
            :since_update_mins =>
              div(NaiveDateTime.diff(NaiveDateTime.utc_now(), last_updated_naive), 60),
            :ids => ids
          })

        {:error, err} ->
          case err do
            :uninitialized ->
              Map.merge(
                %{error: "Server is booting, page is not ready yet..."},
                stringify_type(type)
              )

            :genserver_timeout ->
              Map.merge(
                %{
                  error:
                    "Page is currently being updated, there may be issues displaying the information..."
                },
                stringify_type(type)
              )
          end
      end

    conn =
      if Map.has_key?(data, :error) do
        conn
        |> put_flash(:error, data[:error])
      else
        conn
      end

    # cache IDs so that if this is being updated the site doesnt go down
    # if data doest have the :ids key, set it here

    cachex_key = "#{type}-ids"

    {conn, data} =
      if length(Map.get(data, :ids, [])) == 0 do
        # if data doesn't have ':ids' as a key, try to read from Cachex
        {:ok, has_key} = Cachex.exists?(:unap_html, cachex_key)

        if has_key do
          data = Map.put(data, :ids, Cachex.get!(:unap_html, cachex_key))
          {conn, data}
        else
          {conn |> put_flash(:error, "Error fetching unapproved ids, try again in a minute"),
           Map.put(data, :ids, [])}
        end
      else
        Cachex.put(:unap_html, cachex_key, data[:ids])
        {conn, data}
      end

    # TODO: send current IDs off to data genserver
    # TODO: ask for IDs from data genserver

    {conn, data}
  end

  def anime(conn, _params) do
    {conn, data} = get_data(:anime, conn)
    render(conn, "unapproved.html", data: data)
  end

  def manga(conn, _params) do
    {conn, data} = get_data(:manga, conn)
    render(conn, "unapproved.html", data: data)
  end
end
