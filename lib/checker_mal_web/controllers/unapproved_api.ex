defmodule CheckerMalWeb.UnapprovedAPIController do
  use CheckerMalWeb, :controller

  alias CheckerMalWeb.UnapprovedController

  defp parse_limit(nil), do: nil

  defp parse_limit({limit, _}) when is_integer(limit), do: limit

  defp parse_limit(:error), do: nil

  defp parse_limit(limit) when is_bitstring(limit), do: parse_limit(Integer.parse(limit))

  def request(conn, params, type) when is_atom(type) do
    stype = Atom.to_string(type)

    # use helpers to fetch data using shared HTML unapproved controller functions
    ids = UnapprovedController.get_data(type)[:ids]

    # limit if user requested -- no need to optimize, this is all in memory anyways
    limit = parse_limit(Map.get(params, "limit"))

    ids =
      if is_nil(limit) do
        ids
      else
        Enum.take(ids, limit)
      end

    if Enum.empty?(ids) do
      conn |> put_status(503)
    else
      info = UnapprovedController.fetch_metadata(stype, ids)

      json_formatted =
        ids
        |> Enum.map(fn id ->
          metadata = Map.get(info, id, %{})

          %{
            id: id,
            name: metadata[:name],
            nsfw: metadata[:nsfw],
            type: metadata[:type]
          }
        end)

      json(conn, json_formatted)
    end
  end

  def anime(conn, params), do: request(conn, params, :anime)
  def manga(conn, params), do: request(conn, params, :manga)
end
