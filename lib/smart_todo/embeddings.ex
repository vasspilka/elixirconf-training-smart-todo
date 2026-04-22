defmodule SmartTodo.Embeddings do
  @moduledoc """
  Embeddings context for semantic search and deduplication.
  Indexes cards by generating vector embeddings, then queries by cosine similarity.
  """

  import Ecto.Query
  import Pgvector.Ecto.Query

  alias SmartTodo.Repo
  alias SmartTodo.Todos.Card
  alias SmartTodo.Embeddings.Client

  @batch_size 100

  @doc """
  Indexes all cards that don't have an embedding yet.

  Builds a text representation from each card's fields, generates embeddings
  via the client, and bulk-updates them. Processes in batches of #{@batch_size}.

  Returns `{:ok, count}` with the number of cards indexed,
  or `{:error, reason}` on failure.
  """
  def index do
    cards =
      Card
      |> where([c], is_nil(c.embedding))
      |> where([c], is_nil(c.archived_at))
      |> Repo.all()

    if cards == [] do
      {:ok, 0}
    else
      cards
      |> Enum.chunk_every(@batch_size)
      |> Enum.reduce_while({:ok, 0}, fn batch, {:ok, total} ->
        case index_batch(batch) do
          {:ok, count} -> {:cont, {:ok, total + count}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp index_batch(cards) do
    texts = Enum.map(cards, &card_text/1)

    case Client.embed(texts) do
      {:ok, embeddings} ->
        count =
          cards
          |> Enum.zip(embeddings)
          |> Enum.reduce(0, fn {card, embedding}, acc ->
            {:ok, _} =
              card
              |> Ecto.Changeset.change(%{embedding: Pgvector.new(embedding)})
              |> Repo.update()

            acc + 1
          end)

        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Searches cards by semantic similarity to the given query.

  Embeds the search prompt and queries cards by cosine similarity.
  Returns the top-N closest matches with their similarity scores.

  Options:
    - `:limit` - number of results (default: 10)
    - `:board_id` - scope to a specific board

  Returns `{:ok, [{card, score}]}` or `{:error, reason}`.
  """
  def search(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    board_id = Keyword.get(opts, :board_id)

    case Client.embed_one(query) do
      {:ok, embedding} ->
        vector = Pgvector.new(embedding)

        results =
          Card
          |> where([c], is_nil(c.archived_at))
          |> where([c], not is_nil(c.embedding))
          |> maybe_filter_board(board_id)
          |> select([c], {c, cosine_distance(c.embedding, ^vector)})
          |> order_by([c], cosine_distance(c.embedding, ^vector))
          |> limit(^limit)
          |> Repo.all()
          |> Enum.map(fn {card, distance} -> {card, 1.0 - distance} end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds groups of potentially duplicate cards on a board by comparing embeddings.

  Returns `{:ok, groups}` where each group is a list of `{card, similarity}` tuples,
  or `{:error, reason}`.
  """
  def find_duplicates(board_id, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.85)

    cards =
      Card
      |> where(board_id: ^board_id)
      |> where([c], is_nil(c.archived_at))
      |> where([c], not is_nil(c.embedding))
      |> Repo.all()

    groups =
      cards
      |> find_similar_pairs(threshold)
      |> merge_groups()

    {:ok, groups}
  end

  defp find_similar_pairs(cards, threshold) do
    for {a, i} <- Enum.with_index(cards),
        {b, j} <- Enum.with_index(cards),
        i < j,
        similarity = cosine_similarity(a.embedding, b.embedding),
        similarity >= threshold do
      {a.id, b.id, similarity}
    end
  end

  defp cosine_similarity(vec_a, vec_b) do
    a = Pgvector.to_list(vec_a)
    b = Pgvector.to_list(vec_b)

    dot = Enum.zip(a, b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
    norm_a = :math.sqrt(Enum.reduce(a, 0.0, fn x, acc -> acc + x * x end))
    norm_b = :math.sqrt(Enum.reduce(b, 0.0, fn x, acc -> acc + x * x end))

    if norm_a == 0.0 or norm_b == 0.0, do: 0.0, else: dot / (norm_a * norm_b)
  end

  defp merge_groups(pairs) do
    pairs
    |> Enum.reduce(%{}, fn {a_id, b_id, _sim}, groups ->
      group_a = Map.get(groups, a_id)
      group_b = Map.get(groups, b_id)

      case {group_a, group_b} do
        {nil, nil} ->
          ref = make_ref()
          groups |> Map.put(a_id, ref) |> Map.put(b_id, ref)

        {ref, nil} ->
          Map.put(groups, b_id, ref)

        {nil, ref} ->
          Map.put(groups, a_id, ref)

        {ref_a, ref_b} when ref_a == ref_b ->
          groups

        {ref_a, ref_b} ->
          # Merge group_b into group_a
          groups
          |> Enum.map(fn {id, ref} -> if ref == ref_b, do: {id, ref_a}, else: {id, ref} end)
          |> Map.new()
      end
    end)
    |> Enum.group_by(fn {_id, ref} -> ref end, fn {id, _ref} -> id end)
    |> Map.values()
  end

  defp card_text(%Card{} = card) do
    parts =
      [
        card.title,
        card.description,
        if(card.priority, do: "Priority: #{card.priority}"),
        if(card.labels not in [nil, []], do: "Labels: #{Enum.join(card.labels, ", ")}")
      ]
      |> Enum.reject(&is_nil/1)

    Enum.join(parts, ". ")
  end

  defp maybe_filter_board(query, nil), do: query
  defp maybe_filter_board(query, board_id), do: where(query, board_id: ^board_id)
end
