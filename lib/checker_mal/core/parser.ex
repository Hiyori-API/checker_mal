defmodule CheckerMal.Core.Parser do
  @moduledoc """
  Requests and parses the HTML response from a anime/manga search, extracts names and IDs from the response
  """
  alias CheckerMal.Core.Scraper
  alias CheckerMal.Core.URL

  require Logger

  @doc """
  Interface to this module, requests and parses a page from MAL
  Returns a list of {integer, title}
  """
  def request(type, rating, page) do
    case URL.build_url(type, rating, page) |> Scraper.rated_http_get() do
      {:ok, response_text} ->
        parse_page(response_text)

      {:err, error} ->
        Logger.error(error)
        # maybe error here instead? so it restarts? if rated_http_get has failed
        # (and that has backoff), should it fail completely?
        []
    end
  end

  @doc """
  Parses a list of IDs (integers) and titles from the HTML response
  returns a list of {integer, title}
  """
  def parse_page(response_text) when is_bitstring(response_text) do
    {:ok, document} = Floki.parse_document(response_text)

    Floki.find(document, "div#content div.js-categories-seasonal table tr")
    |> tl()
    |> Enum.map(&parse_list_item(&1))
    |> debug_first()
  end

  defp debug_first(parsed_trs) when is_list(parsed_trs) do
    Logger.debug(
      "First item from response: " <> (parsed_trs |> hd() |> Tuple.to_list() |> Enum.join(" "))
    )

    parsed_trs
  end

  # return {ID, Title} from the Floki object
  def parse_list_item(floki_list_item) do
    tds = floki_list_item |> Floki.find("td")
    pic_obj = tds |> Enum.at(0) |> Floki.find("a")
    link_obj = tds |> Enum.at(1) |> Floki.find("a strong")

    {pic_obj |> Floki.attribute("href") |> hd() |> parse_id_from_mal_url(),
     link_obj |> Floki.text() |> String.trim()}
  end

  @doc ~S"""
  iex> CheckerMal.Core.Parser.parse_id_from_mal_url("https://myanimelist.net/anime/14023/Something_else")
  14023
  iex> CheckerMal.Core.Parser.parse_id_from_mal_url("https://myanimelist.net/manga/30593")
  30593
  """
  def parse_id_from_mal_url(mal_url) when is_bitstring(mal_url) do
    Regex.run(~r/https:\/\/myanimelist.net\/(?:anime|manga)\/(\d+)/, mal_url,
      capture: :all_but_first
    )
    |> hd()
    |> String.to_integer()
  end
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

  @doc """
  Helper to build a URL, given a type, rating and a page
  """
  def build_url(type, rating, page) when is_atom(type) and is_atom(rating) and is_integer(page) do
    base_url =
      case type do
        :anime ->
          anime_page(page)

        :manga ->
          manga_page(page)
      end

    case rating do
      :sfw ->
        base_url |> sfw()

      :nsfw ->
        base_url |> nsfw()
    end
  end
end
