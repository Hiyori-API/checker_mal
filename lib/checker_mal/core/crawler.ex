defmodule CheckerMal.Core.Crawler do
  @moduledoc """
  handles sending requests, backing off, options for requests
  """

  use GenServer

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # state holds options
  def init(init_state \\ %{}) do
    {:ok, init_state}
  end

  def handle_cast({:randomize_user_agent}, state) do
    # TODO: randomize user agent using Faker
    {:noreply, state}
  end

  # returns a function which calls the HTTPoison.get with the correct arguments/options
  def handle_call({:gen_request, url, headers, options}, state) do
    # TODO: inject user agent (headers is a list of tuple pairs, describing headers
    {:reply, fn -> HTTPoison.get(url, headers, Map.put(options, :recv_timeout, :timer.seconds(30))) end, state}
  end
end
