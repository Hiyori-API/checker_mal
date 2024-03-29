defmodule CheckerMalWeb.Router do
  use CheckerMalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CheckerMalWeb do
    pipe_through :browser

    # get "/", PageController, :index
  end

  if Application.compile_env(:checker_mal, :unapproved_html_enabled, false) do
    scope Application.compile_env(:checker_mal, :unapproved_html_basepath, "/mal_unapproved"),
          CheckerMalWeb do
      pipe_through :browser

      get "/", UnapprovedController, :anime
      get "/anime", UnapprovedController, :anime
      get "/manga", UnapprovedController, :manga
    end
  end

  # Other scopes may use custom stacks.
  scope "/api", CheckerMalWeb do
    pipe_through :api

    get "/pages/", RequestPagesController, :request
    get "/debug/", RequestPagesController, :debug
  end

  @unapproved_api Application.compile_env(
                    :checker_mal,
                    :unapproved_api_basepath,
                    "/mal_unapproved/api"
                  )

  scope @unapproved_api, CheckerMalWeb do
    pipe_through :api

    get "/anime/", UnapprovedAPIController, :anime
    get "/manga/", UnapprovedAPIController, :manga
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: CheckerMalWeb.Telemetry
    end
  end
end
