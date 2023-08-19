# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config

database_url =
  Path.expand(System.get_env("DATABASE_PATH")) ||
    raise """
    environment variable DATABASE_PATH is missing.
    this should be a path to the sqlite db
    """

config :checker_mal, CheckerMal.Repo,
  # ssl: true,
  database: database_url,
  # dont really need a big pool, everything is stored in memory
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "2")

secret_key_base =
  System.get_env("CHECKER_MAL_SECRET") ||
    raise """
    environment variable CHECKER_MAL_SECRET is missing.
    You can generate one by calling: mix phx.gen.secret
    """

config :checker_mal, CheckerMalWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT") || "4001"),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key_base

# ## Using releases (Elixir v1.9+)
#
# If you are doing OTP releases, you need to instruct Phoenix
# to start each relevant endpoint:
#
#     config :checker_mal, CheckerMalWeb.Endpoint, server: true
#
# Then you can assemble a release by calling `mix release`.
# See `mix help release` for more information.
