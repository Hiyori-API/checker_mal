defmodule CheckerMal.Repo.Migrations.CreatePagestate do
  use Ecto.Migration

  def change do
    create table(:pagestate) do
      add :timeframe, :string
      add :period, :integer
      add :type, :string

      timestamps()
    end
  end
end
