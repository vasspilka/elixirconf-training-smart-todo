defmodule SmartTodo.LLM.ToolsTest do
  @moduledoc """
  Live tests for Phase 2: intent detection and tool-based command execution.
  These call the real LLM API.
  """
  use SmartTodo.DataCase

  @moduletag :live

  setup do
    {:ok, board} = SmartTodo.Todos.create_board(%{title: "Test Board", position: 0})

    {:ok, todo_list} =
      SmartTodo.Todos.create_list(%{title: "To Do", board_id: board.id, position: 0})

    {:ok, done_list} =
      SmartTodo.Todos.create_list(%{title: "Done", board_id: board.id, position: 1})

    {:ok, card} =
      SmartTodo.Todos.create_card(%{
        title: "Fix login bug",
        board_id: board.id,
        list_id: todo_list.id,
        position: 0,
        priority: "medium"
      })

    %{board: board, todo_list: todo_list, done_list: done_list, card: card}
  end

  describe "detect_intent/2" do
    test "detects create_card intent" do
      {:ok, intents} = SmartTodo.LLM.detect_intent("Add a task to set up CI")
      assert "create_card" in intents
    end

    test "detects move_card intent" do
      {:ok, intents} = SmartTodo.LLM.detect_intent("Move the login task to Done")
      assert "move_card" in intents
    end

    test "detects archive_card intent" do
      {:ok, intents} = SmartTodo.LLM.detect_intent("Archive the completed tasks")
      assert "archive_card" in intents
    end

    test "detects update_card intent" do
      {:ok, intents} = SmartTodo.LLM.detect_intent("Set the login bug to urgent priority")
      assert "update_card" in intents
    end

    test "detects create_list intent" do
      {:ok, intents} = SmartTodo.LLM.detect_intent("Create a new list called In Progress")
      assert "create_list" in intents
    end
  end

  describe "execute_command/3" do
    test "moves a card to a different list", %{board: board, card: card, done_list: done_list} do
      context = %{board_name: board.title, lists: ["To Do", "Done"]}

      {:ok, response} =
        SmartTodo.LLM.execute_command("Move the login bug to Done", board.id, context)

      assert is_binary(response)

      updated_card = SmartTodo.Todos.get_card!(card.id)
      assert updated_card.list_id == done_list.id
    end

    test "creates a new list", %{board: board} do
      context = %{board_name: board.title, lists: ["To Do", "Done"]}

      {:ok, response} =
        SmartTodo.LLM.execute_command("Create a list called In Progress", board.id, context)

      assert is_binary(response)

      list = SmartTodo.Todos.get_list_by_title(board.id, "In Progress")
      assert list != nil
    end

    test "archives a card", %{board: board, card: card} do
      context = %{board_name: board.title, lists: ["To Do", "Done"]}

      {:ok, response} =
        SmartTodo.LLM.execute_command("Archive the login bug", board.id, context)

      assert is_binary(response)

      updated_card = SmartTodo.Todos.get_card!(card.id)
      assert updated_card.archived_at != nil
    end

    test "updates card priority", %{board: board, card: card} do
      context = %{board_name: board.title, lists: ["To Do", "Done"]}

      {:ok, response} =
        SmartTodo.LLM.execute_command(
          "Set the login bug to urgent priority",
          board.id,
          context
        )

      assert is_binary(response)

      updated_card = SmartTodo.Todos.get_card!(card.id)
      assert updated_card.priority == :urgent
    end
  end
end
