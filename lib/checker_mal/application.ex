defmodule CheckerMal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      CheckerMal.Repo,
      # Start the Telemetry supervisor
      CheckerMalWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CheckerMal.PubSub},
      # Start the Endpoint (http/https)
      CheckerMalWeb.Endpoint,
      CheckerMal.Core.RateLimit,
      CheckerMal.Core.Unapproved,
      CheckerMal.Core.Scheduler
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CheckerMal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    CheckerMalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
