defmodule CheckerMal.Core.Parser.Test do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias CheckerMal.Core.Parser

  def id_subset_same(resp_items, subset_list) do
    MapSet.subset?(
      subset_list |> MapSet.new(),
      resp_items |> Enum.map(fn {id, _name} -> id end) |> MapSet.new()
    )
  end

  test "anime page" do
    use_cassette "test_anime_page" do
      items = Parser.request(:anime, :sfw, 1)
      assert items |> length() == 50
      assert id_subset_same(items, [43_917, 43_814, 43_763])
      {_id, name} = items |> hd()
      assert name == "Viola wa Utau"
    end
  end

  test "manga page" do
    use_cassette "test_manga_page" do
      items = Parser.request(:manga, :nsfw, 1)
      assert items |> length() == 50
      assert id_subset_same(items, [130_543, 124_528, 126_708])
    end
  end
end
