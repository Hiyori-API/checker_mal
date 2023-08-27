defmodule CheckerMal.Core.Unapproved.Parser.Test do
  use ExUnit.Case, async: true
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias CheckerMal.Core.Unapproved.Parser

  @tag :skip
  test "parse unapproved id page" do
    use_cassette "test_unapproved_page_parse" do
      %{
        "all_anime" => all_anime,
        "all_manga" => all_manga
      } = Parser.request()

      assert all_anime |> Enum.count() > 25000
      assert all_manga |> Enum.count() > 72000

      assert all_anime |> Enum.all?(&is_integer/1)
      assert all_manga |> Enum.all?(&is_integer/1)
    end
  end
end
