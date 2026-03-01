defmodule SmartTodo.Todos do
  import Ecto.Query

  alias SmartTodo.Repo
  alias SmartTodo.Todos.{Board, List, Card}

  # Boards

  def list_boards do
    Board |> order_by(:position) |> Repo.all()
  end

  def get_board!(id), do: Repo.get!(Board, id)

  def get_board_by_title(title) do
    search = ilike_search(title)

    Board
    |> where([b], ilike(b.title, ^search))
    |> limit(1)
    |> Repo.one()
  end

  def create_board(attrs \\ %{}) do
    %Board{}
    |> Board.changeset(attrs)
    |> Repo.insert()
  end

  def update_board(%Board{} = board, attrs) do
    board
    |> Board.changeset(attrs)
    |> Repo.update()
  end

  def delete_board(%Board{} = board), do: Repo.delete(board)

  def change_board(%Board{} = board, attrs \\ %{}) do
    Board.changeset(board, attrs)
  end

  # Lists

  def list_lists(board_id) do
    List
    |> where(board_id: ^board_id)
    |> order_by(:position)
    |> Repo.all()
  end

  def get_list!(id), do: Repo.get!(List, id)

  def get_list_by_title(board_id, title) do
    search = ilike_search(title)

    List
    |> where(board_id: ^board_id)
    |> where([l], ilike(l.title, ^search))
    |> limit(1)
    |> Repo.one()
  end

  def create_list(attrs \\ %{}) do
    %List{}
    |> List.changeset(attrs)
    |> Repo.insert()
  end

  def update_list(%List{} = list, attrs) do
    list
    |> List.changeset(attrs)
    |> Repo.update()
  end

  def delete_list(%List{} = list), do: Repo.delete(list)

  def change_list(%List{} = list, attrs \\ %{}) do
    List.changeset(list, attrs)
  end

  # Cards

  def list_cards(board_id) do
    Card
    |> where(board_id: ^board_id)
    |> where([c], is_nil(c.archived_at))
    |> order_by(:position)
    |> Repo.all()
  end

  def get_card!(id), do: Repo.get!(Card, id)

  def get_card_by_title(board_id, title) do
    search = ilike_search(title)

    Card
    |> where(board_id: ^board_id)
    |> where([c], is_nil(c.archived_at))
    |> where([c], ilike(c.title, ^search))
    |> limit(1)
    |> Repo.one()
  end

  def search_cards(board_id, query) do
    search = ilike_search(query)

    Card
    |> where(board_id: ^board_id)
    |> where([c], is_nil(c.archived_at))
    |> where([c], ilike(c.title, ^search) or ilike(c.description, ^search))
    |> order_by(:position)
    |> Repo.all()
  end

  def create_card(attrs \\ %{}) do
    %Card{}
    |> Card.changeset(attrs)
    |> Repo.insert()
  end

  def update_card(%Card{} = card, attrs) do
    card
    |> Card.changeset(attrs)
    |> Repo.update()
  end

  def delete_card(%Card{} = card), do: Repo.delete(card)

  def change_card(%Card{} = card, attrs \\ %{}) do
    Card.changeset(card, attrs)
  end

  def move_card(%Card{} = card, list_id, position) do
    card
    |> Card.changeset(%{list_id: list_id, position: position})
    |> Repo.update()
  end

  def archive_card(%Card{} = card) do
    card
    |> Card.changeset(%{archived_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  def unarchive_card(%Card{} = card) do
    card
    |> Card.changeset(%{archived_at: nil})
    |> Repo.update()
  end

  # Reordering

  def reorder_cards(ordered_ids, list_id) do
    Repo.transaction(fn ->
      ordered_ids
      |> Enum.with_index()
      |> Enum.each(fn {card_id, index} ->
        from(c in Card, where: c.id == ^card_id)
        |> Repo.update_all(set: [position: index, list_id: list_id])
      end)
    end)
  end

  # Board loading

  defp ilike_search(term) do
    escaped = String.replace(term, ~r/[%_\\]/, "\\\\\\0")
    "%#{escaped}%"
  end

  def get_board_with_data!(id) do
    cards_query = from c in Card, where: is_nil(c.archived_at), order_by: c.position

    Board
    |> Repo.get!(id)
    |> Repo.preload(lists: {from(l in List, order_by: l.position), cards: cards_query})
  end
end
