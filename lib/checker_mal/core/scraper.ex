defmodule CheckerMal.Core.Scraper do
  @moduledoc """
  Handles requesting/backoff for any particular endpoint
  This specifies "MAL" as the endpoint to the rate_limit GenServer
  """

  require Logger

  @wait_time Application.compile_env(:checker_mal, :mal_wait_time, 15)
  @error_wait_time Application.compile_env(:checker_mal, :mal_error_wait_time, :timer.minutes(1))

  # returns a function which you should call right before the API is used,
  # to update when that endpoint was last used
  defp wait_for_rate_limit() do
    case GenServer.call(
           CheckerMal.Core.RateLimit,
           {:check_rate, "MAL", @wait_time}
         ) do
      {:ok, call_func} ->
        call_func

      {:error, wait_seconds} ->
        # add a 100ms buffer so when wait_seconds == 0 (less than a second away from rate being able to be used)
        # so were not sending a bunch of messages back and forth to the genserver
        :timer.sleep(:timer.seconds(wait_seconds) + 100)
        wait_for_rate_limit()
    end
  end

  # note: the only time this might fail as a rate limit would be if MAL is down (which would cause
  # minute long sleeps in the rated_http_recurse function anyways, or when unapproved is being requested
  @spec rated_http_get(url :: binary, headers :: list, options :: list) ::
          {:ok, String.t()} | {:error, String.t()}
  @doc """
  Transparently rate limits requests to MAL
  """
  def rated_http_get(url, headers \\ [], options \\ [])
      when is_bitstring(url) and is_list(headers) and is_list(options) do
    use_rate_limit = wait_for_rate_limit()
    # add "Mozilla/5.0 (X11; Linux x86_64; rv:136.0) Gecko/20100101 Firefox/136.0" to headers
    headers = [
      {"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:136.0) Gecko/20100101 Firefox/136.0"}
      | headers
    ]

    {allow_errors, options} = Keyword.pop(options, :allow_errors, false)

    if not is_boolean(allow_errors) do
      raise ArgumentError, "allow_errors must be a boolean, received: #{inspect(allow_errors)}"
    end

    # set recv_timeout
    # if HTTP error occurs, wait/sleep and recurse
    http_resp =
      rated_http_recurse(
        fn ->
          HTTPoison.get(url, headers, Keyword.put(options, :recv_timeout, :timer.minutes(1)))
        end,
        0,
        5,
        allow_errors
      )

    # call the function to update when this rate limit was last used
    use_rate_limit.()
    http_resp
  end

  # times: number of times this request has already been tried
  # giveup how many requests to do for this URL before giving up
  @spec rated_http_recurse(
          req_func :: function,
          times :: Integer.t(),
          giveup :: Integer.t(),
          allow_errors :: boolean()
        ) ::
          {:ok, String.t()} | {:error, String.t()}
  defp rated_http_recurse(req_func, times, giveup, allow_errors)
       when is_function(req_func) and is_integer(times) and is_integer(giveup) and
              is_boolean(allow_errors) do
    case req_func.() do
      {:ok, %HTTPoison.Response{status_code: status, body: body_text, request_url: req_url}} ->
        cond do
          status < 400 ->
            {:ok, body_text}

          status >= 400 and status <= 500 and allow_errors ->
            Logger.warning("#{req_url} failed with code #{status}, but errors are allowed:")
            {:ok, body_text}

          true ->
            Logger.warning("#{req_url} failed with code #{status}:")
            handle_backoff(req_func, times, giveup, allow_errors, body_text)
        end

      # unrecoverable HTTP error, perhaps a timeout?
      {:error, err} ->
        handle_backoff(req_func, times, giveup, allow_errors, err)
    end
  end

  defp handle_backoff(req_func, times, giveup, allow_errors, err) do
    Logger.warning("Request failed, waiting and retrying...")
    Logger.error(err)

    if times >= giveup do
      {:error, "Failed too many times..."}
    else
      :timer.sleep(@error_wait_time)
      rated_http_recurse(req_func, times + 1, giveup, allow_errors)
    end
  end
end
