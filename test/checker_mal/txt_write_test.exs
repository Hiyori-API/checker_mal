defmodule CheckerMal.Backend.Txt.Test do
  use ExUnit.Case, async: true

  alias CheckerMal.Backend.Txt
  alias CheckerMal.Core.FeedItem

  test 'write' do
    {:ok, tmp_path} = Temp.path()
    File.mkdir!(tmp_path)

    Application.put_env(:checker_mal, :txt_backend_directory, tmp_path)

    assert Path.join(tmp_path, "anime_sfw.txt") == Txt.filepath(:anime, :sfw)

    target_cachepath = Txt.filepath(:anime, :sfw)
    assert not File.exists?(target_cachepath)

    # initial data
    file = File.open!(target_cachepath, [:write])
    IO.binwrite(file, "4\n10\n15")
    File.close(file)

    assert File.exists?(target_cachepath)

    assert Txt.read(:anime, :sfw) == [4, 10, 15]

    Txt.write(
      [
        %FeedItem{mal_id: 50, action: :added},
        %FeedItem{mal_id: 55, action: :added},
        %FeedItem{mal_id: 1004, action: :added},
        %FeedItem{mal_id: 10, action: :removed},
        %FeedItem{mal_id: 15, action: :removed}
      ],
      :anime,
      :sfw
    )

    assert Txt.read(:anime, :sfw) == [4, 50, 55, 1004]
  end
end
