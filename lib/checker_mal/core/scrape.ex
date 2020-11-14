defmodule CheckerMal.Core.Scrape do
  @moduledoc """
  Handles parsing search pages from MAL

  For reference, see the Jikan XPath selectors from here:
  This doesnt have to parse all that information, since all we need is the MAL id from each page
  https://github.com/jikan-me/jikan/blob/master/src/Parser/Search/AnimeSearchParser.php
  """

  # returns a function which you should call right before the API is used,
  # to update when that endpoint was last used
  def wait_for_rate_limit() do
    case GenServer.call(CheckerMal.RateLimit, {:check_rate, "MAL", Application.get_env(:checker_mal, :mal_wait_time, 15)}) do
      {:ok, call_func} ->
        call_func
      {:error, wait_seconds} ->
        # add a 100ms buffer so when wait_seconds == 0 (less than a second away from rate limit)
        # were not sending a bunch of messages back and forth to the genserver
        :timer.sleep(:timer.seconds(wait_seconds) + 100)
        wait_for_rate_limit()
    end
  end

  def request(url, headers, options) do
    wait_for_rate_limit().()  # call the function to update when this rate limit was last used
    # call CheckerMal.Core.Crawler here to get the function

  end
end


defmodule CheckerMal.Core.Scrape.URL do
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

defmodule CheckerMal.Core.Scrape.ListParser do
  @moduledoc """
  Takes the HTML response from a anime/manga search, extracts names and IDs from the response
  """
end

