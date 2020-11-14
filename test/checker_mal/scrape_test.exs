defmodule CheckerMal.Core.Scrape.Test do
  use ExUnit.Case
  alias CheckerMal.Core.URL

  test "anime URL build fails" do
    assert_raise FunctionClauseError, fn ->
      URL.anime_page(0)
    end
  end

  test "anime URL base" do
    assert URL.anime_page(1) ==
             "https://myanimelist.net/anime.php?q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2&show=0"
  end

  test "anime URL page 2" do
    assert URL.anime_page(2) ==
             "https://myanimelist.net/anime.php?q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2&show=50"
  end

  test "manga URL page 2" do
    assert URL.manga_page(2) ==
             "https://myanimelist.net/manga.php?q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2&show=50"
  end

  test "build URL sfw" do
    assert URL.anime_page(3) |> URL.sfw() == "https://myanimelist.net/anime.php?q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2&show=100&genre[]=12&gx=1"
  end

  test "build URL nsfw" do
    assert URL.anime_page(1) |> URL.nsfw() == "https://myanimelist.net/anime.php?q=&c[0]=a&c[1]=b&c[2]=c&c[3]=d&c[4]=e&c[5]=f&c[6]=g&o=9&w=1&cv=2&show=0&genre[]=12&gx=0"
  end

end
