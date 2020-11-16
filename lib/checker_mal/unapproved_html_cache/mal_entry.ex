defmodule CheckerMal.MALEntry do
  @moduledoc """
  The MALEntry context.
  """

  import Ecto.Query, warn: false
  alias CheckerMal.Repo

  alias CheckerMal.MALEntry.MALEntryData

  @doc """
  Returns the list of malentry.

  ## Examples

      iex> list_malentry()
      [%MALEntryData{}, ...]

  """
  def list_malentry do
    Repo.all(MALEntryData)
  end

  @doc """
  Gets a single mal_entry_data.

  Raises `Ecto.NoResultsError` if the Mal entry data does not exist.

  ## Examples

      iex> get_mal_entry_data!(123)
      %MALEntryData{}

      iex> get_mal_entry_data!(456)
      ** (Ecto.NoResultsError)

  """
  def get_mal_entry_data!(id), do: Repo.get!(MALEntryData, id)

  @doc """
  Creates a mal_entry_data.

  ## Examples

      iex> create_mal_entry_data(%{field: value})
      {:ok, %MALEntryData{}}

      iex> create_mal_entry_data(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_mal_entry_data(attrs \\ %{}) do
    %MALEntryData{}
    |> MALEntryData.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a mal_entry_data.

  ## Examples

      iex> update_mal_entry_data(mal_entry_data, %{field: new_value})
      {:ok, %MALEntryData{}}

      iex> update_mal_entry_data(mal_entry_data, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_mal_entry_data(%MALEntryData{} = mal_entry_data, attrs) do
    mal_entry_data
    |> MALEntryData.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a mal_entry_data.

  ## Examples

      iex> delete_mal_entry_data(mal_entry_data)
      {:ok, %MALEntryData{}}

      iex> delete_mal_entry_data(mal_entry_data)
      {:error, %Ecto.Changeset{}}

  """
  def delete_mal_entry_data(%MALEntryData{} = mal_entry_data) do
    Repo.delete(mal_entry_data)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking mal_entry_data changes.

  ## Examples

      iex> change_mal_entry_data(mal_entry_data)
      %Ecto.Changeset{data: %MALEntryData{}}

  """
  def change_mal_entry_data(%MALEntryData{} = mal_entry_data, attrs \\ %{}) do
    MALEntryData.changeset(mal_entry_data, attrs)
  end
end
