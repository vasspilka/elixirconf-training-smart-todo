defmodule SmartTodo.LLMTest do
  @moduledoc """
  Live tests for SmartTodo.LLM — these call the real LLM API.
  Tag with :live so they can be excluded from CI runs.
  """
  use ExUnit.Case

  @moduletag :live

  describe "parse_cards/2" do
    test "parses multiple cards from natural language" do
      {:ok, cards} = SmartTodo.LLM.parse_cards("Add three tasks for CI: lint, test, deploy")

      assert length(cards) == 3
      titles = Enum.map(cards, & &1["title"])
      assert Enum.any?(titles, &String.contains?(String.downcase(&1), "lint"))
      assert Enum.any?(titles, &String.contains?(String.downcase(&1), "test"))
      assert Enum.any?(titles, &String.contains?(String.downcase(&1), "deploy"))
    end

    test "extracts priority when specified" do
      {:ok, [card]} =
        SmartTodo.LLM.parse_cards("Create an urgent task to fix the login bug")

      assert card["priority"] in ["urgent", "high"]
      assert is_binary(card["title"])
    end

    test "extracts labels and due dates" do
      {:ok, [card]} =
        SmartTodo.LLM.parse_cards(
          "Add a backend task: implement user authentication API, due 2025-03-15, labels: auth, api"
        )

      assert is_binary(card["title"])
      assert card["due_date"] == "2025-03-15"
      assert is_list(card["labels"])
      assert "auth" in card["labels"] or "api" in card["labels"]
    end

    test "handles board context" do
      context = %{board_name: "Sprint 1", lists: ["To Do", "In Progress", "Done"]}
      {:ok, cards} = SmartTodo.LLM.parse_cards("Add a task to set up the database", context)

      assert length(cards) >= 1
      assert hd(cards)["title"] |> is_binary()
    end
  end
end
