defmodule CheckerMal.Utils.TimeShift do
  import Ecto.Query, warn: false

  @doc """
  Changes the value of the 'updated_at' value in the database
  """
  def shift(timeframe, amount, units \\ :second, type \\ :anime) when is_integer(amount) do
    query =
      from c in "pagestate",
        where: c.timeframe == ^timeframe and c.type == ^Atom.to_string(type),
        select: {c.id, c.updated_at}

    {page_id, prev_at} = CheckerMal.Repo.one!(query)

    query =
      from c in "pagestate",
        where: c.id == ^page_id,
        update: [set: [updated_at: ^NaiveDateTime.add(prev_at, amount, units)]]

    CheckerMal.Repo.update_all(query, [])
  end
end
