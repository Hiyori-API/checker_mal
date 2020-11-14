defmodule CheckerMal.Core.Index do
  @moduledoc """
  Checks for new anime/manga entries on MAL

  This module should be backend agnostic, doesnt matter if youre fetching
  items from mongodb and sending requests back, or loading local JSON files
  and writing back changes
  """

  alias CheckerMal.Core.Parser

  @doc """
  Updates either :anime or :manga for a particular page range
  If it finds entries, it extends by how far it checks

  Accepts a MapSet of integers which are the previously approved items
  This returns a list of FeedItem structs, which can then be processed by the caller

  old_items (the MapSet) should only have the items for this rating and type

  see below for type/rating
  """
  def find_new(old_items, type, rating, no_of_pages)
      when is_atom(type) and is_atom(rating) and is_integer(no_of_pages) do
    # TODO: Debug log the first few entries for each page
  end
end

defmodule CheckerMal.Core.Index.FeedItem do
  @moduledoc """
  Represents a MAL item that was approved, deleted or changed in some way
  """

  # type: :anime or :manga
  # rating: :sfw or :nsfw
  # action: :added, :removed or :changed
  # :changed is for possible future usage
  defstruct type: :anime,
            mal_id: -1,
            rating: :sfw,
            action: :added
end
