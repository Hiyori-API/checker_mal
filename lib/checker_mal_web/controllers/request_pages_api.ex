defmodule CheckerMalWeb.RequestPagesController do
  use CheckerMalWeb, :controller

  def request(conn, params) do
    err = validate_params(params["pages"], params["type"])

    if is_nil(err) do
      resp =
        GenServer.call(
          CheckerMal.Core.Scheduler,
          {:add_http_request, String.to_integer(params["pages"]), convert_type(params["type"])}
        )

      json(conn, %{status: resp})
    else
      conn
      |> put_status(400)
      |> json(err)
    end
  end

  defp validate_params(pages, _type) when is_nil(pages),
    do: %{status: :error, msg: "No 'pages' GET argument supplied"}

  defp validate_params(_pages, type) when is_nil(type),
    do: %{status: :error, msg: "No 'type' GET argument supplied"}

  defp validate_params(_pages, type) when is_bitstring(type) do
    if is_nil(convert_type(type)) do
      %{status: :error, msg: "The 'type' GET argument must be either 'anime' or 'manga'"}
    else
      nil
    end
  end

  defp convert_type("anime"), do: :anime
  defp convert_type("manga"), do: :manga
  defp convert_type(_), do: nil
end
