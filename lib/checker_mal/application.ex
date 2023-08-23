defmodule CheckerMal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  defp unapproved_html() do
    if Application.get_env(:checker_mal, :unapproved_html_enabled, false) do
      [
        CheckerMal.UnapprovedHtml.EntryCache,
        CheckerMal.UnapprovedHtml.Cache
      ]
    else
      []
    end
  end

  # skip starting the entry caching and cache genservers in test
  defp state_genservers() do
    if Mix.env() == :test do
      []
    else
      [
        CheckerMal.Core.Unapproved,
        CheckerMal.Core.Scheduler
      ] ++
        unapproved_html()
    end
  end

  def start(_type, _args) do
    children =
      [
        # Start the Ecto repository
        CheckerMal.Repo,
        # Start the Telemetry supervisor
        CheckerMalWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: CheckerMal.PubSub},
        # Start the Endpoint (http/https)
        CheckerMalWeb.Endpoint,
        CheckerMal.Core.RateLimit
      ] ++
        state_genservers()

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
