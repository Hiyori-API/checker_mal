defmodule CheckerMal.Core.RateLimit do
  @moduledoc """
  Global Rate Limit for any number of endpoints

  Tried :ex_rated (module) but it would sometimes return early; probably meant to be used for more than one call

  Whenever you use an API, call:
  GenServer.cast(CheckerMal.Core.RateLimit, {:used, "Website"})

  To check if its been 5 seconds since you've last requested
  GenServer.call(CheckerMal.Core.RateLimit, {:check_rate, "Website", 5})
  Returns
    {:ok, <function which calls :used for this endpoint>}
  or
    {:err, seconds_till_you_should_request_again}}
  """

  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(init_state \\ %{}) do
    {:ok, init_state}
  end

  # for_external_api is some string to define the interaction, i.e. the site this rate limit is for
  # this should be received whenever a request is sent to the 'for_external_api' API
  def handle_cast({:used, for_external_api}, state) do
    state = Map.put(state, for_external_api, DateTime.utc_now())
    {:noreply, state}
  end

  # check if the last time we recfor_external_api
  def handle_call({:check_rate, for_external_api, seconds_elapsed}, _from, state)
      when is_integer(seconds_elapsed) do
    now = DateTime.utc_now()

    approved =
      cond do
        # dont rate limit requests while testing
        Mix.env() == :test ->
          true

        # never been used, allow usage immediately
        Map.has_key?(state, for_external_api) == false ->
          true

        true ->
          DateTime.diff(now, Map.get(state, for_external_api)) > seconds_elapsed
      end

    if approved do
      # dont set the state here, caller should handle that using the function returned from here
      {:reply,
       {:ok, fn -> GenServer.cast(CheckerMal.Core.RateLimit, {:used, for_external_api}) end},
       state}
    else
      {:reply, {:error, seconds_elapsed - DateTime.diff(now, Map.get(state, for_external_api))},
       state}
    end
  end
end
