defmodule SmartTodo.LLM.ResearchAgentTest do
  @moduledoc """
  Tests for Phase 6: Research Agent.

  Unit tests verify tools configuration and integration wiring.
  Live tests (tagged :live) call real LLM and web APIs.
  """
  use SmartTodo.DataCase

  alias SmartTodo.LLM.ResearchAgent
  alias SmartTodo.LLM.Tools
  alias SmartTodo.EvalHelpers
  alias SmartTodo.Todos

  # -------------------------------------------------------------------
  # Unit tests — no external API calls
  # -------------------------------------------------------------------

  describe "tools configuration" do
    setup do
      {:ok, board} = Todos.create_board(%{title: "Test Board", position: 0})
      {:ok, _list} = Todos.create_list(%{title: "To Do", board_id: board.id, position: 0})
      %{board: board}
    end

    test "tool_names includes research" do
      assert "research" in Tools.tool_names()
    end

    test "board_read_tools returns only list_cards", %{board: board} do
      tools = Tools.board_read_tools(board.id)
      assert length(tools) == 1
      assert hd(tools).name == "list_cards"
    end

    test "agent_tools includes board tools and search but not research_agent", %{board: board} do
      tools = Tools.agent_tools(board.id)
      names = Enum.map(tools, & &1.name)

      assert "list_cards" in names
      assert "create_list" in names
      assert "create_card" in names
      assert "move_card" in names
      assert "update_card" in names
      assert "archive_card" in names
      assert "search_cards" in names
      refute "research_agent" in names
    end

    test "chat_tools includes research_agent alongside other tools", %{board: board} do
      tools = Tools.chat_tools(board.id)
      names = Enum.map(tools, & &1.name)

      assert "research_agent" in names
      assert "search_cards" in names
      assert "create_card" in names
    end

    test "chat_tools has one more tool than agent_tools (research_agent)", %{board: board} do
      chat = Tools.chat_tools(board.id)
      agent = Tools.agent_tools(board.id)

      assert length(chat) == length(agent) + 1
    end
  end

  describe "board_context_prompt/1" do
    test "returns empty string for empty context" do
      assert SmartTodo.LLM.board_context_prompt(%{}) == ""
    end

    test "renders board with lists and cards" do
      context = %{
        board_name: "My Board",
        lists: [
          %{
            title: "To Do",
            cards: [
              %{title: "Task 1", priority: "high", labels: ["bug"], due_date: ~D[2026-01-01]}
            ]
          },
          %{title: "Done", cards: []}
        ]
      }

      result = SmartTodo.LLM.board_context_prompt(context)

      assert result =~ "My Board"
      assert result =~ "To Do"
      assert result =~ "Task 1"
      assert result =~ "high"
      assert result =~ "bug"
      assert result =~ "Done"
      assert result =~ "empty"
    end
  end

  # -------------------------------------------------------------------
  # Live tests — call real LLM + web APIs
  # -------------------------------------------------------------------

  describe "run/4 in preview mode" do
    @describetag :live

    setup do
      EvalHelpers.create_eval_board()
    end

    test "researches a topic and returns findings text", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      {:ok, response} =
        ResearchAgent.run(
          "Research best practices for Elixir application deployment",
          board.id,
          context,
          mode: :preview
        )

      assert is_binary(response)
      assert String.length(response) > 100
    end

    test "does not create cards in preview mode", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      board_before = Todos.get_board_with_data!(board.id)
      count_before = count_all_cards(board_before)

      {:ok, _response} =
        ResearchAgent.run(
          "Research monitoring tools for web applications",
          board.id,
          context,
          mode: :preview
        )

      board_after = Todos.get_board_with_data!(board.id)
      count_after = count_all_cards(board_after)
      assert count_after == count_before
    end
  end

  describe "run/4 in autonomous mode" do
    @describetag :live

    setup do
      EvalHelpers.create_eval_board()
    end

    test "researches and creates cards on the board", %{board: board} do
      context = EvalHelpers.build_board_context(board.id)

      board_before = Todos.get_board_with_data!(board.id)
      count_before = count_all_cards(board_before)

      {:ok, response} =
        ResearchAgent.run(
          "Research and create tasks for setting up a basic health check endpoint in an Elixir Phoenix app",
          board.id,
          context,
          mode: :autonomous
        )

      assert is_binary(response)

      board_after = Todos.get_board_with_data!(board.id)
      count_after = count_all_cards(board_after)
      assert count_after > count_before
    end
  end

  describe "intent detection for research" do
    @describetag :live

    @research_prompts [
      "Research best practices for Kubernetes deployment and create tasks",
      "Create a plan for setting up CI/CD pipelines",
      "Look up how to implement rate limiting and make tasks for it"
    ]

    for prompt <- @research_prompts do
      test "detects research intent for: #{prompt}" do
        {:ok, intents} = SmartTodo.LLM.detect_intent(unquote(prompt))

        assert "research" in intents,
               "Expected 'research' in intents for '#{unquote(prompt)}', got: #{inspect(intents)}"
      end
    end
  end

  # -------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------

  defp count_all_cards(board) do
    board.lists |> Enum.map(fn l -> length(l.cards) end) |> Enum.sum()
  end
end
