defmodule CheckerMalWeb.PageController do
  use CheckerMalWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
