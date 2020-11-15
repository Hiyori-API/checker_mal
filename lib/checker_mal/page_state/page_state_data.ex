defmodule CheckerMal.PageState.PageStateData do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pagestate" do
    field :period, :integer
    field :timeframe, :string
    field :type, :string

    timestamps()
  end

  @doc false
  def changeset(page_state_data, attrs) do
    page_state_data
    |> cast(attrs, [:timeframe, :period, :type])
    |> validate_required([:timeframe, :period, :type])
  end
end
