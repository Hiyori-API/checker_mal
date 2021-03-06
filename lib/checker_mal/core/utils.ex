defmodule CheckerMal.Core.Utils do
  def reverse_sort(enum), do: enum |> Enum.sort(fn a, b -> a > b end)
  def last(enum), do: enum |> Enum.take(-1) |> hd()
  def mapset_to_reverse_sorted(mapset), do: mapset |> MapSet.to_list() |> reverse_sort()
end
