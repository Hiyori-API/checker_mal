defmodule CheckerMal.Core.FeedItem do
  @moduledoc """
  Represents a MAL item that was approved, deleted or changed in some way
  """

  # mal_id # id added or removed
  # action: :added, :removed or :changed
  # :changed is for possible future usage
  # the type (anime/manga) and rating (sfw/nsfw)
  # arent needed here since they're passed around
  # as arguments from the scheduler to the backend,
  # so it would just be dupliting info
  defstruct mal_id: -1,
            action: :added
end

defmodule CheckerMal.Core.Index do
  @moduledoc """
  Checks for new anime/manga entries on MAL

  This module should be backend agnostic, doesnt matter if youre fetching
  items from mongodb and sending requests back, or loading local files
  and writing back changes
  """

  alias CheckerMal.Core.Parser
  alias CheckerMal.Core.FeedItem
  alias CheckerMal.Core.Utils
  alias CheckerMal.Core.Unapproved.Wrapper
  alias CheckerMal.Backend.EntryPoint
  require Logger

  @doc """
  Recieves requests to update pages

  Reads from the source backend
  Requests number of pages using stop strategy,
  sending any updates to the Backend.Entrypoint
  """
  def request(type, pages, finished_callback) when is_atom(type) do
    # most of the time, pages is a bitstring, from the db read by the scheduler
    # stop_strategy is a number if nothing else matches,
    # which pattern matches on the find_new with no atom
    stop_strategy =
      cond do
        is_atom(pages) ->
          pages

        is_integer(pages) ->
          pages

        # no page_range here since that should just pass a number
        pages in ["unapproved", "infinite", "one", "testing"] ->
          String.to_atom(pages)

        true ->
          String.to_integer(pages)
      end

    Logger.info("Starting search: #{type} #{stop_strategy} (NSFW)")
    # search NSFW pages
    # can ignore the reached page here, since there
    # are far more (11x) SFW entries
    {_reached_page, new_nsfw_structs} =
      find_new(
        EntryPoint.read(type, :nsfw) |> MapSet.new(),
        type,
        :nsfw,
        if is_number(stop_strategy) do
          ceil(stop_strategy / 5)
        else
          stop_strategy
        end
      )

    Logger.info("Starting search: #{type} #{stop_strategy} (SFW)")
    # search SFW pages
    {reached_page, new_sfw_structs} =
      find_new(
        EntryPoint.read(type, :sfw) |> MapSet.new(),
        type,
        :sfw,
        stop_strategy
      )

    # write back to backend
    EntryPoint.write(new_nsfw_structs, type, :nsfw)
    EntryPoint.write(new_sfw_structs, type, :sfw)
    # send message to scheduler process, notifying it
    # that we're done, and how many pages were processed
    finished_callback.(
      reached_page,
      cond do
        is_integer(stop_strategy) ->
          :page_range

        is_atom(stop_strategy) ->
          stop_strategy

        true ->
          raise "Unexpected stop strategy, not an atom or a number #{stop_strategy}"
      end,
      type
    )
  end

  @doc """
  Updates either :anime or :manga for a particular page range
  If it finds entries, it extends by how far it checks

  Accepts a MapSet of integers which are the previously approved items
  This returns a list of FeedItem structs, which can then be processed by the caller

  old_items (the MapSet) should only have the items for this rating and type

  # type: :anime or :manga
  # rating: :sfw or :nsfw

  stop_strategy is :page_range, :unapproved, or :infinite
  :page_range => request a certain amount of pages, extend if items are found
  :one => only request the cur_page, then exit immediately
  :unapproved => request till we've requested all unapproved items
  :infinite => request all items
  :testing => used while testing, typically only runs one loop
  """
  def find_new(old_items, type, rating, no_of_pages) when is_integer(no_of_pages) do
    add_from_page(
      type,
      rating,
      old_items,
      Utils.mapset_to_reverse_sorted(old_items),
      [],
      :page_range,
      no_of_pages,
      1
    )
  end

  # continue checking pages till we pass the last unapproved item
  def find_new(old_items, type, rating, :unapproved) do
    add_from_page(
      type,
      rating,
      old_items,
      Utils.mapset_to_reverse_sorted(old_items),
      [],
      :unapproved,
      false,
      1
    )
  end

  # continue checking pages till we check all pages
  def find_new(old_items, type, rating, :infinite) do
    add_from_page(
      type,
      rating,
      old_items,
      Utils.mapset_to_reverse_sorted(old_items),
      [],
      :infinite,
      2,
      1
    )
  end

  # page_number is the page to search for IDs
  def find_new(old_items, type, rating, :one, page_number) do
    add_from_page(
      type,
      rating,
      old_items,
      Utils.mapset_to_reverse_sorted(old_items),
      [],
      :one,
      page_number + 1,
      page_number
    )
  end

  # base case
  def add_from_page(_, _, _, _, new_structs, :page_range, till_page, cur_page)
      when cur_page > till_page,
      do: {cur_page - 1, new_structs}

  # :testing atom is used while testing, returns once new_structs have at least one item, typically
  # after one recurse
  def add_from_page(_, _, _, _, new_structs, :testing, _, cur_page) when length(new_structs) > 0,
    do: {cur_page - 1, new_structs}

  # base case for unapproved items
  def add_from_page(_, _, _, _, new_structs, :unapproved, true, cur_page),
    do: {cur_page - 1, new_structs}

  # base case for requesting a single page, till_page is always set to true after
  # a single recurse
  def add_from_page(_, _, _, _, new_structs, :one, true, cur_page),
    do: {cur_page - 1, new_structs}

  # old_items: the MapSet of items from find_new
  # sorted_items: a sorted list of old_items
  def add_from_page(
        type,
        rating,
        old_items,
        sorted_items,
        new_structs,
        stop_strategy,
        till_page,
        cur_page
      ) do
    # request/parse this page from MAL
    ids_on_page =
      Parser.request(type, rating, cur_page, debug: true)
      |> Enum.map(fn {id, _name} -> id end)
      |> Utils.reverse_sort()

    # if there are no items on the page, exit
    # :infinite would exit here or at the bottom if length(ids_on_page) != 50,
    # since the above add_from_page base case doesn't apply
    if ids_on_page |> length() == 0 do
      {cur_page, new_structs}
    else
      # get the min/max id on page
      max_id_on_page = ids_on_page |> hd()
      min_id_on_page = ids_on_page |> Utils.last()

      # to be able to check if items have been deleted, strategy is
      # to compare the sub list of sorted_items between the max and min and
      # comparing that to the ids parsed on the page
      #
      # if some item is in the approved set that is between the min and max ID on the page
      # but wasn't parsed from the page, it should be removed from the approved set
      #
      # to get the sublist:
      # * drop items from the front of the sorted list while they're greater than the max ID
      # * take items from the list while they're greater than the min ID
      sorted_sublist =
        sorted_items
        |> Enum.drop_while(fn n -> n > max_id_on_page end)
        |> Enum.take_while(fn n -> n >= min_id_on_page end)

      # for my sanity later:
      # drop_while is > since we want to include n if its the max ID
      # take_while is >= since we want to include n if its the min ID

      # set difference of (previously approved) - (whats between the min/max ID from the page)
      not_present_in_search =
        MapSet.difference(MapSet.new(sorted_sublist), MapSet.new(ids_on_page))

      # log out deleted IDs
      not_present_in_search
      |> Enum.each(fn n ->
        Logger.info(
          "Removing ID not found in search between #{max_id_on_page} and #{min_id_on_page}: #{n}"
        )
      end)

      # find any items that are in the search page that arent in the set
      new_ids =
        ids_on_page
        |> Enum.filter(fn id -> not MapSet.member?(old_items, id) end)

      # log out added IDs
      new_ids
      |> Enum.each(fn id ->
        Logger.info("Adding new ID on page: #{cur_page}: #{id}")
      end)

      # combine newly approved items with anything deleted
      new_structs =
        Enum.concat([
          new_structs,
          Enum.map(not_present_in_search, fn id ->
            %FeedItem{mal_id: id, action: :removed}
          end),
          Enum.map(new_ids, fn id ->
            %FeedItem{mal_id: id, action: :added}
          end)
        ])

      # if number of entries != 50, this is the last page
      if ids_on_page |> length() != 50 do
        {cur_page, new_structs}
      else
        # if stop_strategy is page_range,
        # if we found new IDs, if current page + some number > till_page, set new till_page
        # 'some number' increases as the page number increases
        updated_till_page =
          case stop_strategy do
            :page_range ->
              before_till_page = till_page

              new_till_page =
                if new_ids |> length() > 0 do
                  Enum.max([5 + div(cur_page, 5) + cur_page, till_page])
                else
                  till_page
                end

              if before_till_page != new_till_page do
                Logger.info("Extended page range from #{before_till_page} to #{new_till_page}")
              end

              new_till_page

            :unapproved ->
              # this returns a bool, not an integer. the bool is matched in the unapproved base case pattern above
              case type do
                :anime ->
                  min_id_on_page < Wrapper.get_last_anime_id()

                :manga ->
                  min_id_on_page < Wrapper.get_last_manga_id()
              end

            :infinite ->
              cur_page + 1

            # has gone through the loop once; done
            :one ->
              true

            _ ->
              # unknown/:testing, use same
              till_page
          end

        # special case, if this found entries on the last unapproved page
        {updated_till_page, stop_strategy} =
          if stop_strategy == :unapproved and updated_till_page == true and length(new_ids) > 0 do
            # set to infinite, will also mark unapproved as done
            # this is probably only going to happen the first time something
            # is indexed, or when the last entry ID on MAL is approved
            {cur_page + 5, :infinite}
          else
            {updated_till_page, stop_strategy}
          end

        # recurse
        # union the old items with new ones found on this page
        #
        # since lists are O(n), the sorted_items |> drop_while
        # is just so this doesnt scale badly with thousands of entries;
        # it doesn't have to be exact
        add_from_page(
          type,
          rating,
          MapSet.union(old_items, MapSet.new(new_ids)),
          sorted_items |> Enum.drop_while(fn n -> n > min_id_on_page end),
          new_structs,
          stop_strategy,
          updated_till_page,
          cur_page + 1
        )
      end
    end
  end
end
