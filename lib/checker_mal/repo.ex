defmodule CheckerMal.Repo do
  use Ecto.Repo,
    otp_app: :checker_mal,
    adapter: Ecto.Adapters.SQLite3
end
