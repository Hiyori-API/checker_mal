# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# mal index config
config :checker_mal,
  mal_error_wait_time: :timer.minutes(1),
  unapproved_page_expire_time: :timer.hours(3),
  txt_backend_directory: System.get_env("TXT_BACKEND_DIR") || "./cache",
  scheduler_loop_time: :timer.minutes(5),
  source_backend: :txt,
  enabled_backends: [:txt]

# enabled_backends: [:txt, :mongodb]

import_config "pages.exs"

# unapproved html configuration
# optional webapp at /mal_unapproved/
# to display currently unapproved entries
#
# unapproved_check_time: time between checking if theres a new cache in checker_mal
# html_basepath: where pages should be served
# asset_basepath: where assets (css/js) should be served

config :checker_mal,
  unapproved_html_enabled: is_nil(System.get_env("UNAPPROVED_HTML_DISABLED")),
  unapproved_check_time: :timer.minutes(5),
  unapproved_html_basepath: "/mal_unapproved",
  unapproved_asset_basepath: "/mal_unapproved_assets"

# jikan, used for the unapproved html page
config :jikan_ex,
  base_url: "http://localhost:8000/v3/"

# random approved MAL id API
# config :checker_mal,
#  random_api_enabled: true,
#  random_api_check_time: :timer.minutes(10),
#  random_api_basepath: "/api/mal/random"

config :checker_mal,
  ecto_repos: [CheckerMal.Repo]

# Configures the endpoint
config :checker_mal, CheckerMalWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "IYcT26juWUyS5Vx0ptI3GHZOA3qA8Bhgy39YMeqEoJLBfvJqZF1ZDldXsPCqcIhW",
  render_errors: [view: CheckerMalWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: CheckerMal.PubSub,
  live_view: [signing_salt: "5ClqTJQe"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
