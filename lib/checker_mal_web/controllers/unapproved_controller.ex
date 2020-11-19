defmodule CheckerMalWeb.UnapprovedController do
  use CheckerMalWeb, :controller
  require Logger

  @html_basepath Application.get_env(:checker_mal, :unapproved_html_basepath, "/mal_unapproved")

  @error_msg "Server is booting, still fetching IDs, try again in a minute..."
  @update_msg "Warning: page is currently being updated, parts may be broken. Try again in a minute..."

  defp stringify_type(:anime), do: %{type: "anime"}
  defp stringify_type(:manga), do: %{type: "manga"}

  defp get_data(type, conn) do
    last_updated =
      try do
        GenServer.call(CheckerMal.Core.Unapproved, :last_updated_at, :timer.seconds(3))
      catch
        :exit, {:timeout, _err} ->
          Logger.warn("GenServer timeout when trying to fetch when last updated")
          {:error, :genserver_timeout}
      end

    data =
      case last_updated do
        {:ok, last_updated_naive} ->
          # if we received this, the GenServer probably wouldn't be blocked by some other request
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

        {:error, err} ->
          case err do
            :uninitialized ->
              %{error: @error_msg}

            :genserver_timeout ->
              %{warning: @update_msg}
          end
      end

    # flash warnings if page is initializing/updating
    conn =
      cond do
        Map.has_key?(data, :error) ->
          conn
          |> put_flash(:error, data[:error])

        Map.has_key?(data, :warning) ->
          conn
          |> put_flash(:warning, data[:warning])

        true ->
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
          {conn |> put_flash(:error, @error_msg), Map.put(data, :ids, [])}
        end
      else
        Cachex.put(:unap_html, cachex_key, data[:ids])
        {conn, data}
      end

    # get entry info (name/type/nsfw)
    entryinfo =
      GenServer.call(
        CheckerMal.UnapprovedHtml.EntryCache,
        {:get_info, Atom.to_string(type), data[:ids]},
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

    # map so that its easier to use in eex

    data =
      Map.put(data, :info, entryinfo)
      |> Map.put(
        :title,
        "Unapproved MAL Entries - #{Atom.to_string(type) |> String.capitalize()}"
      )
      |> Map.put(:basepath, @html_basepath)
      |> Map.merge(stringify_type(type))

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
