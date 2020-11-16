defmodule CheckerMal.MALEntryTest do
  use CheckerMal.DataCase

  alias CheckerMal.MALEntry

  describe "malentry" do
    alias CheckerMal.MALEntry.MALEntryData

    @valid_attrs %{
      entrytype: "some entrytype",
      mal_id: 42,
      name: "some name",
      nsfw: true,
      type: "some type"
    }
    @update_attrs %{
      entrytype: "some updated entrytype",
      mal_id: 43,
      name: "some updated name",
      nsfw: false,
      type: "some updated type"
    }
    @invalid_attrs %{entrytype: nil, mal_id: nil, name: nil, nsfw: nil, type: nil}

    def mal_entry_data_fixture(attrs \\ %{}) do
      {:ok, mal_entry_data} =
        attrs
        |> Enum.into(@valid_attrs)
        |> MALEntry.create_mal_entry_data()

      mal_entry_data
    end

    test "list_malentry/0 returns all malentry" do
      mal_entry_data = mal_entry_data_fixture()
      assert MALEntry.list_malentry() == [mal_entry_data]
    end

    test "get_mal_entry_data!/1 returns the mal_entry_data with given id" do
      mal_entry_data = mal_entry_data_fixture()
      assert MALEntry.get_mal_entry_data!(mal_entry_data.id) == mal_entry_data
    end

    test "create_mal_entry_data/1 with valid data creates a mal_entry_data" do
      assert {:ok, %MALEntryData{} = mal_entry_data} =
               MALEntry.create_mal_entry_data(@valid_attrs)

      assert mal_entry_data.entrytype == "some entrytype"
      assert mal_entry_data.mal_id == 42
      assert mal_entry_data.name == "some name"
      assert mal_entry_data.nsfw == true
      assert mal_entry_data.type == "some type"
    end

    test "create_mal_entry_data/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = MALEntry.create_mal_entry_data(@invalid_attrs)
    end

    test "update_mal_entry_data/2 with valid data updates the mal_entry_data" do
      mal_entry_data = mal_entry_data_fixture()

      assert {:ok, %MALEntryData{} = mal_entry_data} =
               MALEntry.update_mal_entry_data(mal_entry_data, @update_attrs)

      assert mal_entry_data.entrytype == "some updated entrytype"
      assert mal_entry_data.mal_id == 43
      assert mal_entry_data.name == "some updated name"
      assert mal_entry_data.nsfw == false
      assert mal_entry_data.type == "some updated type"
    end

    test "update_mal_entry_data/2 with invalid data returns error changeset" do
      mal_entry_data = mal_entry_data_fixture()

      assert {:error, %Ecto.Changeset{}} =
               MALEntry.update_mal_entry_data(mal_entry_data, @invalid_attrs)

      assert mal_entry_data == MALEntry.get_mal_entry_data!(mal_entry_data.id)
    end

    test "delete_mal_entry_data/1 deletes the mal_entry_data" do
      mal_entry_data = mal_entry_data_fixture()
      assert {:ok, %MALEntryData{}} = MALEntry.delete_mal_entry_data(mal_entry_data)
      assert_raise Ecto.NoResultsError, fn -> MALEntry.get_mal_entry_data!(mal_entry_data.id) end
    end

    test "change_mal_entry_data/1 returns a mal_entry_data changeset" do
      mal_entry_data = mal_entry_data_fixture()
      assert %Ecto.Changeset{} = MALEntry.change_mal_entry_data(mal_entry_data)
    end
  end
end
