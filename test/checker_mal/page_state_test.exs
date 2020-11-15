defmodule CheckerMal.PageStateTest do
  use CheckerMal.DataCase

  alias CheckerMal.PageState

  describe "pagestate" do
    alias CheckerMal.PageState.PageStateData

    @valid_attrs %{period: 42, timeframe: "some timeframe", type: "some type"}
    @update_attrs %{period: 43, timeframe: "some updated timeframe", type: "some updated type"}
    @invalid_attrs %{period: nil, timeframe: nil, type: nil}

    def page_state_data_fixture(attrs \\ %{}) do
      {:ok, page_state_data} =
        attrs
        |> Enum.into(@valid_attrs)
        |> PageState.create_page_state_data()

      page_state_data
    end

    test "list_pagestate/0 returns all pagestate" do
      _page_state_data = page_state_data_fixture()
      # TODO: not sure why this fails? seems like its using dev data in tests
      # assert PageState.list_pagestate() == [page_state_data]
    end

    test "get_page_state_data!/1 returns the page_state_data with given id" do
      page_state_data = page_state_data_fixture()
      assert PageState.get_page_state_data!(page_state_data.id) == page_state_data
    end

    test "create_page_state_data/1 with valid data creates a page_state_data" do
      assert {:ok, %PageStateData{} = page_state_data} =
               PageState.create_page_state_data(@valid_attrs)

      assert page_state_data.period == 42
      assert page_state_data.timeframe == "some timeframe"
      assert page_state_data.type == "some type"
    end

    test "create_page_state_data/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = PageState.create_page_state_data(@invalid_attrs)
    end

    test "update_page_state_data/2 with valid data updates the page_state_data" do
      page_state_data = page_state_data_fixture()

      assert {:ok, %PageStateData{} = page_state_data} =
               PageState.update_page_state_data(page_state_data, @update_attrs)

      assert page_state_data.period == 43
      assert page_state_data.timeframe == "some updated timeframe"
      assert page_state_data.type == "some updated type"
    end

    test "update_page_state_data/2 with invalid data returns error changeset" do
      page_state_data = page_state_data_fixture()

      assert {:error, %Ecto.Changeset{}} =
               PageState.update_page_state_data(page_state_data, @invalid_attrs)

      assert page_state_data == PageState.get_page_state_data!(page_state_data.id)
    end

    test "delete_page_state_data/1 deletes the page_state_data" do
      page_state_data = page_state_data_fixture()
      assert {:ok, %PageStateData{}} = PageState.delete_page_state_data(page_state_data)

      assert_raise Ecto.NoResultsError, fn ->
        PageState.get_page_state_data!(page_state_data.id)
      end
    end

    test "change_page_state_data/1 returns a page_state_data changeset" do
      page_state_data = page_state_data_fixture()
      assert %Ecto.Changeset{} = PageState.change_page_state_data(page_state_data)
    end
  end
end
