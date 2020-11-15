defmodule CheckerMal.Core.Index.Test do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias CheckerMal.Core.Index
  alias CheckerMal.Core.FeedItem

  test "add/remove for add_from_page" do
    use_cassette "response_set" do
      # doesnt exist, should return a 'FeedItem' with :removed
      prev_ids = [43_916]

      # :testing is a special strategy, which returns after one recurse has been done
      {_reached_page, resp} =
        Index.add_from_page(:anime, :sfw, MapSet.new(prev_ids), prev_ids, [], :testing, 1, 1)

      response_set = MapSet.new(resp)

      approved_response_set =
        response_set |> Enum.filter(fn r -> r.action == :added end) |> MapSet.new()

      assert approved_response_set |> MapSet.size() == 50

      assert MapSet.member?(
               approved_response_set |> Enum.map(fn r -> r.mal_id end) |> MapSet.new(),
               43_917
             )

      deleted_response_set =
        response_set |> Enum.filter(fn r -> r.action == :removed end) |> MapSet.new()

      assert deleted_response_set |> MapSet.size() == 1

      assert MapSet.member?(deleted_response_set, %FeedItem{
               mal_id: 43_916,
               action: :removed
             })
    end
  end
end
