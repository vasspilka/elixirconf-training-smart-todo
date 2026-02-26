defmodule SmartTodo.TodosTest do
  use SmartTodo.DataCase

  alias SmartTodo.Todos
  alias SmartTodo.Todos.{Board, List, Task}

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

  describe "tasks" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Board"})
      {:ok, list} = Todos.create_list(%{title: "List", position: 0, board_id: board.id})
      %{board: board, list: list}
    end

    test "list_tasks/1 returns active tasks for a board", %{board: board, list: list} do
      {:ok, task} =
        Todos.create_task(%{title: "Active", list_id: list.id, board_id: board.id, position: 0})

      {:ok, archived} =
        Todos.create_task(%{title: "Archived", list_id: list.id, board_id: board.id, position: 1})

      Todos.archive_task(archived)

      tasks = Todos.list_tasks(board.id)
      assert length(tasks) == 1
      assert hd(tasks).id == task.id
    end

    test "create_task/1 with valid attrs", %{board: board, list: list} do
      attrs = %{title: "New Task", list_id: list.id, board_id: board.id}
      assert {:ok, %Task{title: "New Task", priority: :medium}} = Todos.create_task(attrs)
    end

    test "create_task/1 without title fails", %{board: board, list: list} do
      assert {:error, changeset} = Todos.create_task(%{list_id: list.id, board_id: board.id})
      assert %{title: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_task/2 changes the task", %{board: board, list: list} do
      {:ok, task} = Todos.create_task(%{title: "Old", list_id: list.id, board_id: board.id})
      assert {:ok, %Task{title: "Updated"}} = Todos.update_task(task, %{title: "Updated"})
    end

    test "delete_task/1 removes the task", %{board: board, list: list} do
      {:ok, task} = Todos.create_task(%{title: "Delete Me", list_id: list.id, board_id: board.id})
      assert {:ok, %Task{}} = Todos.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Todos.get_task!(task.id) end
    end

    test "move_task/3 changes list and position", %{board: board, list: list} do
      {:ok, list2} = Todos.create_list(%{title: "Other", position: 1, board_id: board.id})
      {:ok, task} = Todos.create_task(%{title: "Move Me", list_id: list.id, board_id: board.id})

      assert {:ok, moved} = Todos.move_task(task, list2.id, 5)
      assert moved.list_id == list2.id
      assert moved.position == 5
    end

    test "archive_task/1 sets archived_at", %{board: board, list: list} do
      {:ok, task} =
        Todos.create_task(%{title: "Archive Me", list_id: list.id, board_id: board.id})

      assert is_nil(task.archived_at)

      assert {:ok, archived} = Todos.archive_task(task)
      assert not is_nil(archived.archived_at)
    end

    test "unarchive_task/1 clears archived_at", %{board: board, list: list} do
      {:ok, task} =
        Todos.create_task(%{title: "Unarchive Me", list_id: list.id, board_id: board.id})

      {:ok, archived} = Todos.archive_task(task)
      assert not is_nil(archived.archived_at)

      assert {:ok, unarchived} = Todos.unarchive_task(archived)
      assert is_nil(unarchived.archived_at)
    end

    test "change_task/2 returns a changeset", %{board: board, list: list} do
      {:ok, task} = Todos.create_task(%{title: "Test", list_id: list.id, board_id: board.id})
      assert %Ecto.Changeset{} = Todos.change_task(task)
    end
  end

  describe "get_board_with_data!/1" do
    test "loads board with lists and active tasks ordered by position" do
      {:ok, board} = Todos.create_board(%{title: "Full Board"})
      {:ok, list1} = Todos.create_list(%{title: "First", position: 0, board_id: board.id})
      {:ok, list2} = Todos.create_list(%{title: "Second", position: 1, board_id: board.id})

      {:ok, _t2} =
        Todos.create_task(%{title: "Task 2", position: 1, list_id: list1.id, board_id: board.id})

      {:ok, _t1} =
        Todos.create_task(%{title: "Task 1", position: 0, list_id: list1.id, board_id: board.id})

      {:ok, archived} =
        Todos.create_task(%{
          title: "Archived",
          position: 2,
          list_id: list1.id,
          board_id: board.id
        })

      Todos.archive_task(archived)

      {:ok, _t3} =
        Todos.create_task(%{title: "Task 3", position: 0, list_id: list2.id, board_id: board.id})

      loaded = Todos.get_board_with_data!(board.id)

      assert loaded.title == "Full Board"
      assert [l1, l2] = loaded.lists
      assert l1.title == "First"
      assert l2.title == "Second"

      assert [t1, t2] = l1.tasks
      assert t1.title == "Task 1"
      assert t2.title == "Task 2"

      assert [t3] = l2.tasks
      assert t3.title == "Task 3"
    end
  end
end
