defmodule CheckerMal.Repo do
  use Ecto.Repo,
    otp_app: :checker_mal,
    adapter: Ecto.Adapters.Postgres
end
