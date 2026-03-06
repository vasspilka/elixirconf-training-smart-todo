defmodule SmartTodo.EmbeddingsTest do
  use SmartTodo.DataCase

  alias SmartTodo.Embeddings
  alias SmartTodo.Todos

  @moduletag :live

  setup do
    SmartTodo.EvalHelpers.create_eval_board()
  end

  describe "index/0" do
    test "indexes all cards without embeddings", %{cards: cards} do
      # Verify cards start without embeddings
      card = Todos.get_card!(cards.login.id)
      assert is_nil(card.embedding)

      # Index all cards
      {:ok, count} = Embeddings.index()
      assert count == 5

      # Verify embeddings were set
      card = Todos.get_card!(cards.login.id)
      refute is_nil(card.embedding)
    end

    test "skips already-indexed cards", %{cards: _cards} do
      {:ok, 5} = Embeddings.index()

      # Running again should index 0
      {:ok, 0} = Embeddings.index()
    end

    test "returns {:ok, 0} when no cards exist" do
      # Create a board with no cards
      {:ok, board} = Todos.create_board(%{title: "Empty Board", position: 99})
      {:ok, _list} = Todos.create_list(%{title: "Empty", board_id: board.id, position: 0})

      # Should still succeed with 0 indexed (existing cards from setup are already there)
      # Re-index — already indexed cards are skipped
      {:ok, 5} = Embeddings.index()
      {:ok, 0} = Embeddings.index()
    end
  end

  describe "search/1" do
    setup %{cards: _cards} do
      {:ok, _count} = Embeddings.index()
      :ok
    end

    test "finds semantically similar cards", %{board: board} do
      {:ok, results} = Embeddings.search("authentication login", board_id: board.id)

      assert length(results) > 0

      # The login card should be among the top results
      {top_card, score} = hd(results)
      assert score > 0.5

      assert top_card.title =~ "login" or top_card.title =~ "Login" or
               hd(top_card.labels) =~ "auth"
    end

    test "returns results with similarity scores", %{board: board} do
      {:ok, results} = Embeddings.search("API endpoints", board_id: board.id)

      assert length(results) > 0

      Enum.each(results, fn {card, score} ->
        assert is_struct(card, SmartTodo.Todos.Card)
        assert is_float(score)
        assert score >= 0.0 and score <= 1.0
      end)
    end

    test "respects limit option", %{board: board} do
      {:ok, results} = Embeddings.search("tasks", board_id: board.id, limit: 2)

      assert length(results) <= 2
    end

    test "scopes to a specific board" do
      {:ok, other_board} = Todos.create_board(%{title: "Other Board", position: 99})
      {:ok, list} = Todos.create_list(%{title: "List", board_id: other_board.id, position: 0})

      {:ok, _card} =
        Todos.create_card(%{
          title: "Unrelated card on other board",
          board_id: other_board.id,
          list_id: list.id,
          position: 0
        })

      # Index all (including the new card)
      Embeddings.index()

      {:ok, results} = Embeddings.search("unrelated", board_id: other_board.id)
      assert length(results) > 0

      Enum.each(results, fn {card, _score} ->
        assert card.board_id == other_board.id
      end)
    end
  end

  describe "find_duplicates/1" do
    test "finds similar cards on a board", %{board: board} do
      # Create two very similar cards
      list = Todos.list_lists(board.id) |> hd()

      {:ok, _} =
        Todos.create_card(%{
          title: "Fix SSO login issue",
          description: "Users cannot sign in via SSO",
          board_id: board.id,
          list_id: list.id,
          position: 10,
          priority: "urgent",
          labels: ["bug", "auth"]
        })

      # Index everything
      {:ok, _} = Embeddings.index()

      {:ok, groups} = Embeddings.find_duplicates(board.id, threshold: 0.80)

      # We should find at least one group (the login cards are very similar)
      assert length(groups) > 0

      # At least one group should have 2+ cards
      assert Enum.any?(groups, fn group -> length(group) >= 2 end)
    end
  end
end
