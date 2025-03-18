defmodule CheckerMal.Core.Unapproved do
  @moduledoc """
  This caches unapproved anime and manga IDs on myanimelist.

  In particular, it caches *all* IDs, approved
  and unapproved. In order to compute which ones
  are unapproved, take the set difference with
  the source from CheckerMal.Backend.EntryPoint.read
  """

  alias CheckerMal.Core.Unapproved.Utils
  alias CheckerMal.Core.Unapproved.Parser
  alias CheckerMal.DiscordWebook

  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    state = Map.merge(default_state(), init_state)
    {:ok, state}
  end

  # includes an 'is_updating' field since the request/parsing
  # can take up to a minute
  # else, the GenServer is blocked and timeouts occur while that
  # is happening
  defp default_state(), do: %{"all_anime" => [], "all_manga" => [], "is_updating" => false}

  # if the state has expired, update in the background
  defp update_async(state) do
    if not has_valid_data?(state) do
      # dont run if already updating
      if not state["is_updating"] do
        spawn_link(fn ->
          GenServer.cast(
            CheckerMal.Core.Unapproved,
            {:update_results, Parser.request_or_read_from_cache()}
          )
        end)
      end

      state |> Map.put("is_updating", true)
    else
      state
    end
  end

  # doesn't use state since the results from the scraper and
  # keys the map is merged with accounts for all of the state
  def handle_cast({:update_results, scraper_resp}, _state) do
    Logger.info("Finished parsing ID ajax pages")
    # marks the time and is_updating keys when unapproved page is finished updating
    {:noreply,
     scraper_resp
     |> Map.merge(%{
       "is_updating" => false
     })}
  end

  def handle_call(:get_all_anime, _from, state) do
    state = update_async(state)
    {:reply, Map.get(state, "all_anime"), state}
  end

  def handle_call(:get_all_manga, _from, state) do
    state = update_async(state)
    {:reply, Map.get(state, "all_manga"), state}
  end

  def handle_call(:last_updated_at, _from, state) do
    resp =
      if Map.has_key?(state, "at") do
        {:ok, state["at"]}
      else
        {:error, :uninitialized}
      end

    {:reply, resp, state}
  end

  def handle_call(:has_valid_data?, _from, state),
    do: {:reply, has_valid_data?(state), state}

  def handle_call(:is_updating, _from, state),
    do: {:reply, Map.get(state, "is_updating", true), state}

  defp has_valid_data?(state), do: Utils.has_data?(state) and not Utils.has_expired?(state)
end

defmodule CheckerMal.Core.Unapproved.Utils do
  def has_data?(state), do: Map.get(state, "all_anime", []) |> length() > 0

  @page_expire_time Application.compile_env(
                      :checker_mal,
                      :unapproved_page_expire_time,
                      :timer.hours(6)
                    )

  def has_expired?(state) do
    now = NaiveDateTime.utc_now()

    expire_seconds = div(@page_expire_time, 1000)

    cond do
      not Map.has_key?(state, "at") ->
        true

      NaiveDateTime.diff(now, Map.get(state, "at", now)) > expire_seconds ->
        true

      true ->
        false
    end
  end
end

defmodule CheckerMal.Core.Unapproved.Wrapper do
  @moduledoc """
  Exposes the Genserver.call anime/manga endpoints

  the wait_till_parsed function waits until get_all_anime
  returns some results, can be used in other modules
  to wait in a sleep loop till the GenServer above
  is initialized
  """

  defp get_handler(genserver_atom) when is_atom(genserver_atom),
    do: GenServer.call(CheckerMal.Core.Unapproved, genserver_atom)

  # primarily used on the webpage
  @spec get_all_anime() :: [integer()]
  def get_all_anime(), do: get_handler(:get_all_anime)
  @spec get_all_manga() :: [integer()]
  def get_all_manga(), do: get_handler(:get_all_manga)

  # primarily used in the indexer
  # hd works here since IDs are reverse sorted after being parsed (in table_to_ids)
  @spec get_last_anime_id() :: integer()
  def get_last_anime_id(), do: get_handler(:get_all_anime) |> hd()
  @spec get_last_manga_id() :: integer()
  def get_last_manga_id(), do: get_handler(:get_all_manga) |> hd()

  # this can be called from other modules, to wait in a sleep loop
  # after it returns, other modules can request the get_all_anime
  # and get_all_manga and know they return data
  #
  # this is called in the UnapprovedHtmlEntryCache when it starts,
  # which is what starts the whole genserver process of requesting
  # the unapproved html page and parsing it
  def wait_till_parsed(), do: wait_till_parsed(fn -> get_all_manga() end)

  def wait_till_parsed(request_func) when is_function(request_func),
    do: wait_till_parsed([], request_func)

  # Wrapper.get_all_anime() requests
  # asynchronously, so if it has expired, the next
  # time @unapproved_check_time has elapsed, the items will
  # have updated
  # If get_all_anime returns an empty list, the application
  # probably just started, so we should wait here synchronously
  # so we have to up to date IDs
  def wait_till_parsed([], request_func) when is_function(request_func) do
    :timer.sleep(50)
    wait_till_parsed(request_func.(), request_func)
  end

  # base case
  def wait_till_parsed(results, _request_func) when is_list(results) and length(results) > 0,
    do: results
end

defmodule CheckerMal.Core.Unapproved.Parser do
  alias CheckerMal.Core.Scraper
  alias CheckerMal.Core.Utils
  alias CheckerMal.DiscordWebook
  require Logger

  @anime_ajax_page "https://myanimelist.net/includes/ajax.inc.php?r=___&t=3"
  @manga_ajax_page "https://myanimelist.net/includes/ajax.inc.php?q=___&t=40"

  @doc """
  saves the HTML page to cache
  """
  def save_to_cache(
        data,
        type
      )
      when type in [:anime, :manga] do
    Logger.info("Saving #{type} to cache")
    atom_string = Atom.to_string(type)
    target_dir = File.cwd!() <> "/cache"

    if !File.exists?(target_dir) do
      File.mkdir(target_dir)
    end

    target_file = "#{target_dir}/#{atom_string}.html"
    File.write!(target_file, data)
  end

  defp cache_file(type) when type in [:anime, :manga] do
    atom_string = Atom.to_string(type)
    target_dir = File.cwd!() <> "/cache"
    "#{target_dir}/#{atom_string}.html"
  end

  defp cache_file_updated_at(type) do
    if File.exists?(cache_file(type)) do
      # returns UTC stat time
      {{year, month, day}, {hour, min, sec}} = File.stat!(cache_file(type)).mtime
      NaiveDateTime.new!(year, month, day, hour, min, sec)
    else
      nil
    end
  end

  defp stat_expired?(expire_seconds) do
    now = NaiveDateTime.utc_now()

    anime_stat = cache_file_updated_at(:anime)
    manga_stat = cache_file_updated_at(:manga)

    ret =
      case {anime_stat, manga_stat} do
        {nil, _} ->
          true

        {_, nil} ->
          true

        {_, _} ->
          NaiveDateTime.diff(now, anime_stat) > expire_seconds or
            NaiveDateTime.diff(now, manga_stat) > expire_seconds
      end

    Logger.info(
      "unapproved stat expired (now: #{now}, anime: #{anime_stat}, manga: #{manga_stat}): is expired=#{ret}"
    )

    ret
  end

  defp request_page_and_save_to_cache(
         type,
         test_parse_function
       )
       when type in [:anime, :manga] do
    url =
      case type do
        :anime -> @anime_ajax_page
        :manga -> @manga_ajax_page
      end

    Logger.info("Requesting #{type} ajax page: #{url}")

    case Scraper.rated_http_get(url) do
      {:error, err} ->
        Logger.error(err)

        DiscordWebook.send_error("Failed to request #{type} ajax page")

        {:error, err}

      {:ok, html_response} ->
        # if test_parse_function works, save to cache
        if test_parse_function.(html_response) == :ok do
          html_response |> save_to_cache(type)
        end

        {:ok, html_response}
    end
  end

  # the disable flag is enabled by me if there is some issue
  # connecting to MAL 
  @disable_unapproved_requests Application.compile_env(
                                 :checker_mal,
                                 :disable_unapproved_requests,
                                 false
                               )

  @page_expire_time_ms Application.compile_env(
                         :checker_mal,
                         :unapproved_page_expire_time,
                         :timer.hours(6)
                       )

  @spec read_from_cache_or_request(atom) :: binary | nil
  defp read_from_cache_or_request(type) when type in [:anime, :manga] do
    cf = cache_file(type)

    file_exists_and_not_expired =
      case File.exists?(cf) do
        true ->
          not stat_expired?(div(@page_expire_time_ms, 1000))

        false ->
          true
      end

    # the disable flag is enabled by me if there is some issue
    # connecting to MAL 
    if @disable_unapproved_requests or file_exists_and_not_expired do
      Logger.info("Reading #{type} from cache")
      cf |> File.read!()
    else
      case request_page_and_save_to_cache(type, fn html_response ->
             head_chars = html_response |> String.slice(0..990_999)

             items = parse_ajax_page(head_chars, type, 10)

             cond do
               items == [] ->
                 Logger.error(
                   "No #{type} items found on page, first head_chars chars: #{head_chars}"
                 )

                 DiscordWebook.send_error(
                   "Unapproved page: No #{type} items found in first 5000 chars of ajax search page"
                 )

                 :error

               items |> length() == 10 && items |> Enum.at(0) |> is_integer() ->
                 Logger.info("Successfully parsed #{type} ajax page, #{items}, saving to cache")
                 :ok

               true ->
                 IO.inspect(items)
                 DiscordWebook.send_error("Unapproved page: Could not enough items from #{type}")
                 :error
             end
           end) do
        {:error, err} ->
          Logger.error(err)
          DiscordWebook.send_error("Failed to request #{type} ajax page")
          nil

        {:ok, html_response} ->
          html_response
      end
    end
  end

  # parse a string, returning nil if it can't be parsed 
  defp int_safe(str) do
    case Integer.parse(str) do
      {int, _} ->
        int

      _ ->
        nil
    end
  end

  def parse_ajax_page(nil, type, _limit) do
    DiscordWebook.send_error("No html response received, request for #{type} likely failed")

    nil
  end

  @doc """
  Takes the html response and parses it into a list of anime/manga ids
  """
  @spec parse_ajax_page(binary, atom, integer | nil) :: [integer()]
  # limit defaults to none here, because of the above clause
  def parse_ajax_page(html_response, type, limit)
      when type in [:anime, :manga] and is_binary(html_response) do
    Logger.info("Parsing #{type} ajax page")
    {:ok, doc} = Floki.parse_fragment(html_response)

    # parse all divs, then filter them down to ones that have an attr with id=maMangaTitle320913 for manga and
    # and id=maAnimeTitle555 for anime

    id_value =
      case type do
        :anime -> "maAnimeTitle"
        :manga -> "maMangaTitle"
      end

    # example of node:
    # {"p", [{"class", "headline"}], ["Floki"]}
    iter =
      doc
      |> Floki.find("tr div")
      |> Stream.map(fn item ->
        id = Floki.attribute(item, "id")

        if length(id) > 0 && String.starts_with?(id |> Enum.at(0), id_value) do
          id |> Enum.at(0) |> String.trim_leading(id_value) |> int_safe()
        else
          # this is not a matching div, its probably the name of the entry, return nil
          nil
        end
      end)
      # filter out nils
      |> Stream.filter(&(!is_nil(&1)))

    # let the user take a few items instead of exhausting the whole list, this allows us to
    # test a part of the page to ensure data is being parsed properly
    case limit do
      # when not specified, parses everything from the stream
      nil ->
        iter
        |> Enum.to_list()

      _ ->
        iter
        |> Enum.take(limit)
        |> Enum.to_list()
    end
  end

  @anime_min Application.compile_env(:checker_mal, :unapproved_anime_min)
  @anime_max Application.compile_env(:checker_mal, :unapproved_anime_max)

  @manga_min Application.compile_env(:checker_mal, :unapproved_manga_min)
  @manga_max Application.compile_env(:checker_mal, :unapproved_manga_max)

  def request_or_read_from_cache() do
    anime = read_from_cache_or_request(:anime) |> parse_ajax_page(:anime, nil)
    manga = read_from_cache_or_request(:manga) |> parse_ajax_page(:manga, nil)

    error_if(
      "Number of anime in table (#{length(anime)}) is not in expected_range (#{@anime_min},#{@anime_max})",
      length(anime) not in @anime_min..@anime_max
    )

    error_if(
      "Number of manga in table (#{length(manga)}) is not in expected_range (#{@manga_min},#{@manga_max})",
      length(manga) not in @manga_min..@manga_max
    )

    stat = cache_file_updated_at(:anime)
    error_if("Could not stat anime.html cache file", is_nil(stat))

    %{
      "all_anime" => anime |> Utils.reverse_sort(),
      "all_manga" => manga |> Utils.reverse_sort(),
      "at" => stat
    }
  end

  # @spec parse_unapproved_anime(String.t()) :: %{}
  # def parse_unapproved_anime(html_response) do
  #   {:ok, document} = Floki.parse_document(html_response)
  #
  #   tables = Floki.find(document, "table")
  #
  #   if length(tables) != 3 do
  #     error_msg = "Expected 3 tables, got #{tables |> length()}"
  #
  #     DiscordWebook.send_error(error_msg)
  #
  #     raise error_msg
  #   end
  #
  #   anime_table = tables |> Enum.at(1)
  #   anime_trs = Floki.find(anime_table, "tr")
  #
  #   # this should be the anime rows
  #   anime_table_ids = anime_table_hrefs(anime_trs)
  #
  #   %{
  #     "all_anime" => anime_table_ids
  #   }
  # end
  #
  # @spec anime_table_hrefs([Floki.html_tag()]) :: [integer()]
  # defp anime_table_hrefs(tr_rows) do
  # filter to elements with anchors, first tr could be a header? but I dont
  #   # even want to risk just discarding it, better to filter since webscraping
  #   trs_with_a =
  #     tr_rows
  #     |> Enum.filter(fn tr ->
  #       Floki.find(tr, "a")
  #       |> length() == 1
  #     end)
  #
  #   bebop = trs_with_a |> Enum.at(0) |> Floki.find("td")
  #
  #   if length(bebop) != 3 do
  #     error_msg = "Expected 3 td elements, got #{bebop |> length()}"
  #
  #     DiscordWebook.send_error(error_msg)
  #
  #     raise error_msg
  #   end
  #
  #   # the first td element is the anime ID
  #   # the second td element is the anime name
  #   # the third td element is the anime type
  #
  #   id = bebop |> Enum.at(0, 0) |> Floki.text() |> String.to_integer()
  #   name = bebop |> Enum.at(1, "") |> Floki.text() |> String.trim()
  #   type = bebop |> Enum.at(2, "") |> Floki.text() |> String.trim() |> String.downcase()
  #
  #   error_if("First anime ID in table is not id 1", id != 1)
  #   error_if("First anime name in table is not 'Cowboy Bebop' (#{name})", name != "Cowboy Bebop")
  #   error_if("First anime type in table is not 'tv' (#{type})", type != "tv")
  #
  #   error_if(
  #     "Number of rows (#{length(trs_with_a)}) is not in expected_range (#{@anime_min},#{@anime_max})",
  #     length(trs_with_a) > @anime_max or length(trs_with_a) < @anime_min
  #   )
  #
  #   Logger.info("Anime table has #{length(trs_with_a)} rows")
  #
  #   trs_with_a
  #   |> Floki.find("a")
  #   |> Enum.map(fn {_, _, [id]} -> id end)
  #   |> Enum.map(fn id -> String.to_integer(id) end)
  #   |> Utils.reverse_sort()
  # end
  #
  # @spec parse_unapproved_manga(String.t()) :: %{}
  # def parse_unapproved_manga(html_response) do
  #   {:ok, document} = Floki.parse_document(html_response)
  #
  #   tables = Floki.find(document, "table")
  #
  #   if length(tables) != 3 do
  #     error_msg = "Expected 3 tables, got #{tables |> length()}"
  #
  #     DiscordWebook.send_error(error_msg)
  #
  #     raise error_msg
  #   end
  #
  #   manga_table = tables |> Enum.at(2)
  #   manga_trs = Floki.find(manga_table, "tr")
  #
  #   # this should be the manga rows
  #   manga_table_ids = manga_table_hrefs(manga_trs)
  #
  #   %{
  #     "all_manga" => manga_table_ids
  #   }
  # end
  #
  # @spec manga_table_hrefs([Floki.html_tag()]) :: [integer()]
  # def manga_table_hrefs(tr_rows) do
  #   trs_with_a =
  #     tr_rows
  #     |> Enum.filter(fn tr ->
  #       Floki.find(tr, "a")
  #       |> length() == 1
  #     end)
  #
  #   monster = trs_with_a |> Enum.at(0) |> Floki.find("td")
  #
  #   if length(monster) != 2 do
  #     error_msg = "Expected 2 td elements, got #{monster |> length()}"
  #
  #     DiscordWebook.send_error(error_msg)
  #
  #     raise error_msg
  #   end
  #
  #   id = monster |> Enum.at(0, 0) |> Floki.text() |> String.to_integer()
  #   name = monster |> Enum.at(1, "") |> Floki.text() |> String.trim()
  #   # hmm - this doesn't exist for manga?
  #   # type = monster |> Enum.at(2, "") |> Floki.text() |> String.trim() |> String.downcase()
  #
  #   error_if("First manga ID in table is not id 1", id != 1)
  #   error_if("First manga name in table is not 'Monster' (#{name})", name != "Monster")
  #   # weird...
  #   # error_if("First manga type in table is not 'manga' (#{type})", type != "manga")
  #
  #   error_if(
  #     "Number of rows (#{length(trs_with_a)}) is not in expected_range (#{@manga_min},#{@manga_max})",
  #     length(trs_with_a) > @manga_max or length(trs_with_a) < @manga_min
  #   )
  #
  #   Logger.info("Manga table has #{length(trs_with_a)} rows")
  #
  #   trs_with_a
  #   |> Floki.find("a")
  #   |> Enum.map(fn {_, _, [id]} -> id end)
  #   |> Enum.map(fn id -> String.to_integer(id) end)
  #   |> Utils.reverse_sort()
  # end

  def error_if(msg, true) do
    DiscordWebook.send_error(msg)
    raise msg
  end

  def error_if(_msg, false), do: :ok
end
