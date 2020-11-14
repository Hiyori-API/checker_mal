defmodule CheckerMal.Core.Index do
  @moduledoc """
  Checks for new anime/manga entries on MAL
  Compares against a Set of previously approved items

  This module should be backend agnostic, doesnt matter if youre fetching
  items from mongodb and sending requests back, or loading local JSON files
  and writing back changes

  This returns a list of FeedItem structs, which can then be processed by the caller
  """
end

defmodule CheckerMal.Core.Index.FeedItem do
  @moduledoc """
  Represents a MAL item that was approved, deleted or changed in some way
  """

  # type: :anime or :manga
  # rating: :sfw or :nsfw
  # action: :added or :removed
  defstruct type: :anime,
            mal_id: -1,
            rating: :sfw,
            action: :added
end

defmodule CheckerMal.Core.URL do
  # all columns, no query, ordered by MAL id, reverse
  @base_query 'q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2'

  defp page_helper(media_type, page_number) when is_integer(page_number) do
    show_offset = (page_number - 1) * 50
    "https://myanimelist.net/#{media_type}.php?#{@base_query}&show=#{show_offset}"
  end

  def anime_page(n) when is_integer(n) and n > 0 do
    page_helper("anime", n)
  end

  def manga_page(n) when is_integer(n) and n > 0 do
    page_helper("manga", n)
  end

  def sfw(base_url) do
    base_url <> "&genre[]=12&gx=1"
  end

  def nsfw(base_url) do
    base_url <> "&genre[]=12&gx=0"
  end
end

defmodule CheckerMal.Core.Parser.ListParser do
  @moduledoc """
  Takes the HTML response from a anime/manga search, extracts names and IDs from the response
  """
end
