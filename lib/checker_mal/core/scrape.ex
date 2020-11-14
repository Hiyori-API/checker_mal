defmodule CheckerMal.Core.Scrape do
  @moduledoc """
  Handles parsing search pages from MAL

  For reference, see the Jikan XPath selectors from here:
  This doesnt have to parse all that information, since all we need is the MAL id from each page
  https://github.com/jikan-me/jikan/blob/master/src/Parser/Search/AnimeSearchParser.php
  """
  require Logger

  # returns a function which you should call right before the API is used,
  # to update when that endpoint was last used
  def wait_for_rate_limit() do
    case GenServer.call(CheckerMal.Core.RateLimit, {:check_rate, "MAL", Application.get_env(:checker_mal, :mal_wait_time, 15)}) do
      {:ok, call_func} ->
        call_func
      {:error, wait_seconds} ->
        # add a 100ms buffer so when wait_seconds == 0 (less than a second away from rate limit)
        # were not sending a bunch of messages back and forth to the genserver
        :timer.sleep(:timer.seconds(wait_seconds) + 100)
        wait_for_rate_limit()
    end
  end

  def rated_http_get(url, headers \\ [], options \\ []) when is_bitstring(url) and is_list(headers) and is_list(options) do
    wait_for_rate_limit().()  # call the function to update when this rate limit was last used
    # set recv_timeout
    # if HTTP error occurs, wait/sleep and recurse
    rated_http_recurse(fn -> HTTPoison.get(url, headers, Keyword.put(options, :recv_timeout, :timer.seconds(30))) end)
  end

  # times: number of times this request has already been tried
  # giveup how many requests to do for this URL before giving up
  def rated_http_recurse(req_func, times \\ 0, giveup \\ 10) when is_function(req_func) and is_integer(times) and is_integer(giveup) do
    case req_func.() do
      {:ok, %HTTPoison.Response{status_code: status, body: body_text, request_url: req_url}} ->
        cond do
          status < 400 ->
            {:ok, body_text}
          true ->
            Logger.warn("#{req_url} failed with code #{status}:")
            handle_backoff(req_func, times, giveup, body_text)
        end

      # unrecoverable HTTP error, perhaps a timeout?
      {:error, err} ->
        handle_backoff(req_func, times, giveup, err)
    end
  end

  defp handle_backoff(req_func, times, giveup, err) do
    Logger.error(err)
    if times >= giveup do
      {:error, "Failed too many times..."}
    else
      :timer.sleep(Application.get_env(:checker_mal, :mal_error_wait_time, :timer.minutes(1)))
      rated_http_recurse(req_func, times + 1, giveup)
    end
  end
end

