defmodule CheckerMal.MALEntry.MALEntryData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "malentry" do
    field :entrytype, :string
    field :mal_id, :integer
    field :name, :string
    field :nsfw, :boolean, default: false
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(mal_entry_data, attrs) do
    mal_entry_data
    |> cast(attrs, [:name, :type, :entrytype, :nsfw, :mal_id])
    |> validate_required([:name, :type, :entrytype, :nsfw, :mal_id])
  end
end
