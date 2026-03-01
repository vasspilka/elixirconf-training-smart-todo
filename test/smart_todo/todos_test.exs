defmodule SmartTodo.TodosTest do
  use SmartTodo.DataCase

  alias SmartTodo.Todos
  alias SmartTodo.Todos.{Board, List, Card}

  describe "boards" do
    test "list_boards/0 returns boards ordered by position" do
      {:ok, b2} = Todos.create_board(%{title: "Second", position: 1})
      {:ok, b1} = Todos.create_board(%{title: "First", position: 0})

      assert [%{id: id1}, %{id: id2}] = Todos.list_boards()
      assert id1 == b1.id
      assert id2 == b2.id
    end

    test "get_board!/1 returns the board" do
      {:ok, board} = Todos.create_board(%{title: "Test"})
      assert Todos.get_board!(board.id).id == board.id
    end

    test "create_board/1 with valid attrs" do
      assert {:ok, %Board{title: "New Board"}} = Todos.create_board(%{title: "New Board"})
    end

    test "create_board/1 with missing title fails" do
      assert {:error, changeset} = Todos.create_board(%{})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_board/2 changes the board" do
      {:ok, board} = Todos.create_board(%{title: "Old"})
      assert {:ok, %Board{title: "New"}} = Todos.update_board(board, %{title: "New"})
    end

    test "delete_board/1 removes the board" do
      {:ok, board} = Todos.create_board(%{title: "Delete Me"})
      assert {:ok, %Board{}} = Todos.delete_board(board)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_board!(board.id) end
    end

    test "change_board/2 returns a changeset" do
      {:ok, board} = Todos.create_board(%{title: "Test"})
      assert %Ecto.Changeset{} = Todos.change_board(board)
    end

    test "get_board_by_title/1 finds board by exact title" do
      {:ok, board} = Todos.create_board(%{title: "Marketing"})
      result = Todos.get_board_by_title("Marketing")
      assert result.id == board.id
    end

    test "get_board_by_title/1 finds board case-insensitively" do
      {:ok, board} = Todos.create_board(%{title: "Marketing Plan"})
      result = Todos.get_board_by_title("marketing plan")
      assert result.id == board.id
    end

    test "get_board_by_title/1 returns nil when not found" do
      assert Todos.get_board_by_title("Nonexistent") == nil
    end
  end

  describe "lists" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      %{board: board}
    end

    test "list_lists/1 returns lists for a board ordered by position", %{board: board} do
      {:ok, l2} = Todos.create_list(%{title: "Second", position: 1, board_id: board.id})
      {:ok, l1} = Todos.create_list(%{title: "First", position: 0, board_id: board.id})

      assert [%{id: id1}, %{id: id2}] = Todos.list_lists(board.id)
      assert id1 == l1.id
      assert id2 == l2.id
    end

    test "create_list/1 with valid attrs", %{board: board} do
      assert {:ok, %List{title: "New List"}} =
               Todos.create_list(%{title: "New List", board_id: board.id})
    end

    test "create_list/1 without title fails", %{board: board} do
      assert {:error, changeset} = Todos.create_list(%{board_id: board.id})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_list/2 changes the list", %{board: board} do
      {:ok, list} = Todos.create_list(%{title: "Old", board_id: board.id})
      assert {:ok, %List{title: "New"}} = Todos.update_list(list, %{title: "New"})
    end

    test "delete_list/1 removes the list", %{board: board} do
      {:ok, list} = Todos.create_list(%{title: "Delete Me", board_id: board.id})
      assert {:ok, %List{}} = Todos.delete_list(list)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_list!(list.id) end
    end

    test "change_list/2 returns a changeset", %{board: board} do
      {:ok, list} = Todos.create_list(%{title: "Test", board_id: board.id})
      assert %Ecto.Changeset{} = Todos.change_list(list)
    end
  end

  describe "cards" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      {:ok, list} = Todos.create_list(%{title: "List", position: 0, board_id: board.id})
      %{board: board, list: list}
    end

    test "list_cards/1 returns active cards for a board", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{title: "Active", list_id: list.id, board_id: board.id, position: 0})

      {:ok, archived} =
        Todos.create_card(%{title: "Archived", list_id: list.id, board_id: board.id, position: 1})

      Todos.archive_card(archived)

      cards = Todos.list_cards(board.id)
      assert length(cards) == 1
      assert hd(cards).id == card.id
    end

    test "create_card/1 with valid attrs", %{board: board, list: list} do
      attrs = %{title: "New Card", list_id: list.id, board_id: board.id}
      assert {:ok, %Card{title: "New Card", priority: :medium}} = Todos.create_card(attrs)
    end

    test "create_card/1 without title fails", %{board: board, list: list} do
      assert {:error, changeset} = Todos.create_card(%{list_id: list.id, board_id: board.id})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_card/2 changes the card", %{board: board, list: list} do
      {:ok, card} = Todos.create_card(%{title: "Old", list_id: list.id, board_id: board.id})
      assert {:ok, %Card{title: "Updated"}} = Todos.update_card(card, %{title: "Updated"})
    end

    test "delete_card/1 removes the card", %{board: board, list: list} do
      {:ok, card} = Todos.create_card(%{title: "Delete Me", list_id: list.id, board_id: board.id})
      assert {:ok, %Card{}} = Todos.delete_card(card)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_card!(card.id) end
    end

    test "move_card/3 changes list and position", %{board: board, list: list} do
      {:ok, list2} = Todos.create_list(%{title: "Other", position: 1, board_id: board.id})
      {:ok, card} = Todos.create_card(%{title: "Move Me", list_id: list.id, board_id: board.id})

      assert {:ok, moved} = Todos.move_card(card, list2.id, 5)
      assert moved.list_id == list2.id
      assert moved.position == 5
    end

    test "archive_card/1 sets archived_at", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{title: "Archive Me", list_id: list.id, board_id: board.id})

      assert is_nil(card.archived_at)

      assert {:ok, archived} = Todos.archive_card(card)
      assert not is_nil(archived.archived_at)
    end

    test "unarchive_card/1 clears archived_at", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{title: "Unarchive Me", list_id: list.id, board_id: board.id})

      {:ok, archived} = Todos.archive_card(card)
      assert not is_nil(archived.archived_at)

      assert {:ok, unarchived} = Todos.unarchive_card(archived)
      assert is_nil(unarchived.archived_at)
    end

    test "change_card/2 returns a changeset", %{board: board, list: list} do
      {:ok, card} = Todos.create_card(%{title: "Test", list_id: list.id, board_id: board.id})
      assert %Ecto.Changeset{} = Todos.change_card(card)
    end
  end

  describe "get_card_by_title/2" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      {:ok, list} = Todos.create_list(%{title: "List", position: 0, board_id: board.id})
      %{board: board, list: list}
    end

    test "finds card by title", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{
          title: "Login page",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      result = Todos.get_card_by_title(board.id, "Login page")
      assert result.id == card.id
    end

    test "finds card case-insensitively", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{
          title: "Login page",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      result = Todos.get_card_by_title(board.id, "login")
      assert result.id == card.id
    end

    test "excludes archived cards", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{
          title: "Old login",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      Todos.archive_card(card)

      assert Todos.get_card_by_title(board.id, "login") == nil
    end

    test "returns nil when not found", %{board: board} do
      assert Todos.get_card_by_title(board.id, "nonexistent") == nil
    end
  end

  describe "search_cards/2" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      {:ok, list} = Todos.create_list(%{title: "List", position: 0, board_id: board.id})
      %{board: board, list: list}
    end

    test "finds cards by title", %{board: board, list: list} do
      {:ok, _} =
        Todos.create_card(%{
          title: "Login page bug",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      {:ok, _} =
        Todos.create_card(%{
          title: "Signup form",
          list_id: list.id,
          board_id: board.id,
          position: 1
        })

      results = Todos.search_cards(board.id, "login")
      assert length(results) == 1
      assert hd(results).title == "Login page bug"
    end

    test "finds cards by description", %{board: board, list: list} do
      {:ok, _} =
        Todos.create_card(%{
          title: "Bug fix",
          description: "Fix the authentication flow",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      results = Todos.search_cards(board.id, "authentication")
      assert length(results) == 1
      assert hd(results).title == "Bug fix"
    end

    test "excludes archived cards", %{board: board, list: list} do
      {:ok, card} =
        Todos.create_card(%{
          title: "Archived login task",
          list_id: list.id,
          board_id: board.id,
          position: 0
        })

      Todos.archive_card(card)

      results = Todos.search_cards(board.id, "login")
      assert results == []
    end

    test "returns empty list when no match", %{board: board} do
      assert Todos.search_cards(board.id, "nonexistent") == []
    end
  end

  describe "get_list_by_title/2" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      %{board: board}
    end

    test "finds list by exact title", %{board: board} do
      {:ok, list} = Todos.create_list(%{title: "Done", position: 0, board_id: board.id})

      result = Todos.get_list_by_title(board.id, "Done")
      assert result.id == list.id
    end

    test "finds list case-insensitively", %{board: board} do
      {:ok, list} = Todos.create_list(%{title: "In Progress", position: 0, board_id: board.id})

      result = Todos.get_list_by_title(board.id, "in progress")
      assert result.id == list.id
    end

    test "returns nil when not found", %{board: board} do
      assert Todos.get_list_by_title(board.id, "Nonexistent") == nil
    end
  end

  describe "get_board_with_data!/1" do
    test "loads board with lists and active cards ordered by position" do
      {:ok, board} = Todos.create_board(%{title: "Full Board"})
      {:ok, list1} = Todos.create_list(%{title: "First", position: 0, board_id: board.id})
      {:ok, list2} = Todos.create_list(%{title: "Second", position: 1, board_id: board.id})

      {:ok, _c2} =
        Todos.create_card(%{title: "Card 2", position: 1, list_id: list1.id, board_id: board.id})

      {:ok, _c1} =
        Todos.create_card(%{title: "Card 1", position: 0, list_id: list1.id, board_id: board.id})

      {:ok, archived} =
        Todos.create_card(%{
          title: "Archived",
          position: 2,
          list_id: list1.id,
          board_id: board.id
        })

      Todos.archive_card(archived)

      {:ok, _c3} =
        Todos.create_card(%{title: "Card 3", position: 0, list_id: list2.id, board_id: board.id})

      loaded = Todos.get_board_with_data!(board.id)

      assert loaded.title == "Full Board"
      assert [l1, l2] = loaded.lists
      assert l1.title == "First"
      assert l2.title == "Second"

      assert [c1, c2] = l1.cards
      assert c1.title == "Card 1"
      assert c2.title == "Card 2"

      assert [c3] = l2.cards
      assert c3.title == "Card 3"
    end
  end
end
