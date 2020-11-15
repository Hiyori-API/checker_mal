defmodule CheckerMal.PageState do
  @moduledoc """
  The PageState context.
  """

  import Ecto.Query, warn: false
  alias CheckerMal.Repo

  alias CheckerMal.PageState.PageStateData

  @doc """
  Returns the list of pagestate.

  ## Examples

      iex> list_pagestate()
      [%PageStateData{}, ...]

  """
  def list_pagestate do
    Repo.all(PageStateData)
  end

  @doc """
  Gets a single page_state_data.

  Raises `Ecto.NoResultsError` if the Page state data does not exist.

  ## Examples

      iex> get_page_state_data!(123)
      %PageStateData{}

      iex> get_page_state_data!(456)
      ** (Ecto.NoResultsError)

  """
  def get_page_state_data!(id), do: Repo.get!(PageStateData, id)

  @doc """
  Creates a page_state_data.

  ## Examples

      iex> create_page_state_data(%{field: value})
      {:ok, %PageStateData{}}

      iex> create_page_state_data(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_page_state_data(attrs \\ %{}) do
    %PageStateData{}
    |> PageStateData.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns T/F based on whether or not a timeframe and type is already in the database
  """
  def has_pagestate?(timeframe, type) when is_bitstring(timeframe) and is_bitstring(type) do
    query =
      from c in PageStateData,
        where: c.timeframe == ^timeframe and c.type == ^type,
        select: c.id

    Repo.all(query) |> length() > 0
  end

  def has_pagestate?(timeframe, type) when is_atom(type),
    do: has_pagestate?(timeframe, Atom.to_string(type))

  def insert_pagestate_if_doesnt_exist(timeframe, period, type) when is_atom(type),
    do: insert_pagestate_if_doesnt_exist(timeframe, period, Atom.to_string(type))

  @doc """
  Initializes a pagestate timeframes if a corresponding entry doesnt already exist in the database
  """
  def insert_pagestate_if_doesnt_exist(timeframe, period, type) when is_bitstring(type) do
    if not has_pagestate?(timeframe, type) do
      create_page_state_data(%{period: period, timeframe: timeframe, type: type})
    else
      {:ok, :already_existed}
    end
  end

  @doc """
  Updates a page_state_data.

  ## Examples

      iex> update_page_state_data(page_state_data, %{field: new_value})
      {:ok, %PageStateData{}}

      iex> update_page_state_data(page_state_data, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_page_state_data(%PageStateData{} = page_state_data, attrs) do
    page_state_data
    |> PageStateData.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a page_state_data.

  ## Examples

      iex> delete_page_state_data(page_state_data)
      {:ok, %PageStateData{}}

      iex> delete_page_state_data(page_state_data)
      {:error, %Ecto.Changeset{}}

  """
  def delete_page_state_data(%PageStateData{} = page_state_data) do
    Repo.delete(page_state_data)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page_state_data changes.

  ## Examples

      iex> change_page_state_data(page_state_data)
      %Ecto.Changeset{data: %PageStateData{}}

  """
  def change_page_state_data(%PageStateData{} = page_state_data, attrs \\ %{}) do
    PageStateData.changeset(page_state_data, attrs)
  end
end
