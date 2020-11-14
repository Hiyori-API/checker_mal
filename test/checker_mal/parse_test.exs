defmodule CheckerMal.Core.Parser.Test do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias CheckerMal.Core.Parser

  setup do
    ExVCR.Config.cassette_library_dir("fixture/vcr_cassettes")
    :ok
  end

  def id_subset_same(resp_items, subset_list) do
    MapSet.subset?(
      subset_list |> MapSet.new(),
      resp_items |> Enum.map(fn {id, name} -> id end) |> MapSet.new()
    )
  end

  test "anime page", context do
    use_cassette "test_anime_page" do
      items = Parser.request(:anime, :sfw, 1)
      assert items |> length() == 50
      assert id_subset_same(items, [43917, 43814, 43763])
      {id, name} = items |> hd()
      assert name == "Viola wa Utau"
    end
  end

  test "manga page", context do
    use_cassette "test_manga_page" do
      items = Parser.request(:manga, :nsfw, 1)
      assert items |> length() == 50
      assert id_subset_same(items, [130_543, 124_528, 126_708])
    end
  end
end
