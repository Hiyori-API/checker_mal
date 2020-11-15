defmodule CheckerMal.Backend.Txt do
  @moduledoc """
  Stores the approved IDs for MAL in local txt files, one ID per line
  """
  require Logger

  alias CheckerMal.Core.FeedItem

  def read(type, rating), do: read_or_empty(type, rating)

  def write(new_structs, type, rating) when is_list(new_structs) do
    entries = read_or_empty(type, rating) |> MapSet.new()

    # split feeditem data into added/removed
    structs_map =
      new_structs
      |> Enum.map(fn %FeedItem{mal_id: id, action: action} -> {action, id} end)
      |> Enum.group_by(fn {action, _} -> action end, fn {_, id} -> id end)

    # combine that with read data using sets
    new_entries =
      entries
      |> MapSet.new()
      |> MapSet.union(MapSet.new(Map.get(structs_map, :added, [])))
      |> MapSet.difference(MapSet.new(Map.get(structs_map, :removed, [])))

    # write changes to file
    write_list(new_entries |> MapSet.to_list(), filepath(type, rating))
  end

  # read from the file or return an empty list if it doesnt exist
  defp read_or_empty(type, rating) do
    path = filepath(type, rating)

    if File.exists?(path) do
      File.stream!(path, [:read], :line)
      |> Stream.map(fn ln -> String.trim(ln) end)
      |> Stream.filter(fn ln -> String.length(ln) > 0 end)
      |> Enum.map(fn ln -> String.to_integer(ln) end)
    else
      Logger.warning("Using empty cache for #{type} #{rating}")
      dirname = Path.dirname(path)

      if not File.exists?(dirname) do
        File.mkdir!(dirname)
      end

      File.touch!(path)
      []
    end
  end

  def write_list(ids, path) when is_list(ids) do
    ids
    |> Enum.sort()
    |> Stream.map(fn id -> Integer.to_string(id) <> "\n" end)
    |> Enum.into(File.stream!(path, [:write]))
  end

  def filepath(type, rating) do
    base = Application.get_env(:checker_mal, :txt_backend_directory, "./")
    Path.join(base, "#{Atom.to_string(type)}_#{Atom.to_string(rating)}.txt")
  end
end
