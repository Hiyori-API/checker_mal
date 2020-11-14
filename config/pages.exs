use Mix.Config

# This file describes how many pages should be checked, and how often
# When the last item for each of these page ranges is stored in PostGres,
# it persists across runs
#
# the numbers below describe SFW page ranges, NSFW are requested at the same time,
# running with floor(n/2.5)

defmodule H do
  def days(dys), do: :timer.hours(24) * dys
end

config :checker_mal,
  anime_pages: [
    {3, :timer.minutes(30)},
    {8, :timer.hours(8)},
    {20, H.days(4)},
    {40, H.days(10)},
    {:unapproved, H.days(30)},
    {:all, H.days(60)}
  ],
  manga_pages: [
    {3, :timer.minutes(30)},
    {8, :timer.hours(8)},
    {20, H.days(4)},
    {40, H.days(10)},
    {:unapproved, H.days(30)},
    {:all, H.days(60)}
  ]
