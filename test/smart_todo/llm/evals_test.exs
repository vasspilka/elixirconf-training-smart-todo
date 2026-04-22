defmodule SmartTodo.LLM.EvalsTest do
  @moduledoc """
  Trajectory-based evaluations for LLM agent behavior.

  These tests verify that the LLM calls the right tools with the right arguments
  for common board operations. Tagged :live since they call the real LLM API.
  """
  use SmartTodo.DataCase

  use LangChain.Trajectory.Assertions

  alias LangChain.Trajectory
  alias SmartTodo.EvalHelpers
  alias SmartTodo.Todos

  @moduletag :live

  setup do
    EvalHelpers.create_eval_board()
  end

  describe "move card trajectories" do
    test "moves a single card to a different list", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Move the login bug to In Progress",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "move_card", arguments: nil}
        ], mode: :superset, args: :subset)

      # Verify the card actually moved
      card = Todos.get_card_by_title(board.id, "Fix login bug")
      in_progress = Todos.get_list_by_title(board.id, "In Progress")
      assert card.list_id == in_progress.id
    end

    test "moves multiple cards based on criteria", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Move all urgent cards to In Progress",
          board.id,
          context
        )

      trajectory = Trajectory.from_chain(chain)
      move_calls = Trajectory.calls_by_name(trajectory, "move_card")
      assert length(move_calls) >= 1

      # The urgent card should now be in "In Progress"
      card = Todos.get_card_by_title(board.id, "Fix login bug")
      in_progress = Todos.get_list_by_title(board.id, "In Progress")
      assert card.list_id == in_progress.id
    end
  end

  describe "archive card trajectories" do
    test "archives completed tasks", %{board: board, cards: cards} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Archive all cards in the Done list",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "archive_card", arguments: nil}
        ], mode: :superset)

      # The "Code review for payments" card was in Done — verify it's archived
      updated = Todos.get_card!(cards.review.id)
      assert updated.archived_at != nil
    end

    test "archives a specific card by name", %{board: board, cards: cards} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Archive the documentation card",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "archive_card", arguments: nil}
        ], mode: :superset)

      updated = Todos.get_card!(cards.docs.id)
      assert updated.archived_at != nil
    end
  end

  describe "create card trajectories" do
    test "creates a card in the specified list", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Create a new card called 'Add unit tests' in the To Do list with high priority",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "create_card", arguments: %{"list_name" => "To Do"}}
        ], mode: :superset, args: :subset)

      card = Todos.get_card_by_title(board.id, "Add unit tests")
      assert card != nil
    end
  end

  describe "update card trajectories" do
    test "updates card priority", %{board: board, cards: cards} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Set the documentation card to urgent priority",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "update_card", arguments: nil}
        ], mode: :superset)

      updated = Todos.get_card!(cards.docs.id)
      assert updated.priority == :urgent
    end
  end

  describe "create list trajectories" do
    test "creates a new list on the board", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Create a new list called 'QA Review'",
          board.id,
          context
        )

      assert_trajectory(
        chain,
        [
          %{name: "create_list", arguments: %{"title" => "QA Review"}}
        ], mode: :superset, args: :subset)

      list = Todos.get_list_by_title(board.id, "QA Review")
      assert list != nil
    end
  end

  describe "multi-step trajectories" do
    test "creates a list then adds cards to it", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Create a list called 'Testing' and add a card 'Write integration tests' to it",
          board.id,
          context
        )

      trajectory = Trajectory.from_chain(chain)

      assert_trajectory(
        trajectory,
        [
          %{name: "create_list", arguments: nil},
          %{name: "create_card", arguments: nil}
        ], mode: :superset)

      list = Todos.get_list_by_title(board.id, "Testing")
      assert list != nil
      card = Todos.get_card_by_title(board.id, "Write integration tests")
      assert card != nil
    end
  end

  describe "safety trajectories" do
    test "does not archive cards when asked to move them", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, chain} =
        SmartTodo.LLM.execute_command_chain(
          "Move the login bug to Done",
          board.id,
          context
        )

      refute_trajectory(
        chain,
        [
          %{name: "archive_card", arguments: nil}
        ], mode: :superset)
    end
  end

  describe "intent detection accuracy" do
    @intent_cases [
      {"Add a task to write unit tests", ["create_card"]},
      {"Move the login bug to Done", ["move_card"]},
      {"Archive the completed tasks", ["archive_card"]},
      {"Set the API card to urgent priority", ["update_card"]},
      {"Create a new column called QA", ["create_list"]},
      {"Create a Testing list and add three cards to it", ["create_list", "create_card"]},
      {"We finished the login bug, mark it as done", ["move_card"]},
      {"Remove the documentation task, we don't need it", ["archive_card"]}
    ]

    for {prompt, expected_intents} <- @intent_cases do
      test "detects intent for: #{prompt}" do
        {:ok, intents} = SmartTodo.LLM.detect_intent(unquote(prompt))

        for expected <- unquote(expected_intents) do
          assert expected in intents,
                 "Expected #{expected} in intents for '#{unquote(prompt)}', got: #{inspect(intents)}"
        end
      end
    end
  end
end
