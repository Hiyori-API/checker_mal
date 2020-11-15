defmodule CheckerMal.Backend.Txt do
  @moduledoc """
  Stores the approved IDs for MAL in local txt files, one ID per line
  """
  require Logger

  def read(type, rating), do: read_or_empty(type, rating)

  def write_changes(type, rating, new_structs) do
    # TODO: implement write changes
  end

  # read from the file or return an empty list if it doesnt exist
  defp read_or_empty(type, rating) do
    base = Application.get_env(:checker_mal, :txt_backend_directory, "./")
    path = Path.join(base, "#{Atom.to_string(type)}_#{Atom.to_string(rating)}.txt")

    if File.exists?(path) do
      File.stream!(path)
      |> Stream.map(fn ln -> String.trim(ln) end)
      |> Stream.filter(fn ln -> String.length(ln) > 0 end)
      |> Stream.map(fn ln -> String.to_integer(ln) end)
      |> Enum.to_list()
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
end
