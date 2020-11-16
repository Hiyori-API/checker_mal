defmodule CheckerMal.Repo.Migrations.CreateMalentry do
  use Ecto.Migration

  def change do
    create table(:malentry) do
      add :name, :string
      add :type, :string
      add :entrytype, :string
      add :nsfw, :boolean, default: false, null: false
      add :mal_id, :integer

      timestamps()
    end
  end
end
