use Mix.Config

# TODO: copy this into test.exs so doctests run the same?

# This file describes how many pages should be checked, and how often
# When the last item for each of these page ranges is stored in PostGres,
# it persists across runs
#
# the numbers below describe SFW page ranges, NSFW are requested at the same time,
# running with ceil(n/5)

defmodule T do
  def days(dys) when is_integer(dys), do: :timer.hours(24) * dys
  def ms_to_s(ms), do: div(ms, 1000)
end

# infinite is checking all pages

# the order of pages here describes the hierarchy
# i.e. if we check 40 pages, we can mark 20, 8 and 3 as done
config :checker_mal,
  anime_pages: [
    {3, T.ms_to_s(:timer.hours(1))},
    {8, T.ms_to_s(:timer.hours(8))},
    {20, T.ms_to_s(T.days(4))},
    {40, T.ms_to_s(T.days(10))},
    {:unapproved, T.ms_to_s(T.days(30))},
    {:infinite, T.ms_to_s(T.days(60))}
  ],
  manga_pages: [
    {3, T.ms_to_s(:timer.hours(1))},
    {8, T.ms_to_s(:timer.hours(8))},
    {20, T.ms_to_s(T.days(4))},
    {40, T.ms_to_s(T.days(10))},
    {:unapproved, T.ms_to_s(T.days(30))},
    {:infinite, T.ms_to_s(T.days(60))}
  ]

# reason why this uses seconds instead of ms
# is so that it should fit into the default
# int type for any SQL-type backend
