defmodule CheckerMal.Core.Scrape.Test do
  use ExUnit.Case, async: true
  alias CheckerMal.Core.URL

  doctest URL

  test "anime URL build fails" do
    assert_raise FunctionClauseError, fn ->
      URL.anime_page(0)
    end
  end
end
