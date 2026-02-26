defmodule SmartTodo.Todos do
  import Ecto.Query

  alias SmartTodo.Repo
  alias SmartTodo.Todos.{Board, List, Task}

  # Boards

  def list_boards do
    Board |> order_by(:position) |> Repo.all()
  end

  def get_board!(id), do: Repo.get!(Board, id)

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

  # Tasks

  def list_tasks(board_id) do
    Task
    |> where(board_id: ^board_id)
    |> where([t], is_nil(t.archived_at))
    |> order_by(:position)
    |> Repo.all()
  end

  def get_task!(id), do: Repo.get!(Task, id)

  def create_task(attrs \\ %{}) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
  end

  def delete_task(%Task{} = task), do: Repo.delete(task)

  def change_task(%Task{} = task, attrs \\ %{}) do
    Task.changeset(task, attrs)
  end

  def move_task(%Task{} = task, list_id, position) do
    task
    |> Task.changeset(%{list_id: list_id, position: position})
    |> Repo.update()
  end

  def archive_task(%Task{} = task) do
    task
    |> Task.changeset(%{archived_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update()
  end

  def unarchive_task(%Task{} = task) do
    task
    |> Task.changeset(%{archived_at: nil})
    |> Repo.update()
  end

  # Board loading

  def get_board_with_data!(id) do
    tasks_query = from t in Task, where: is_nil(t.archived_at), order_by: t.position

    Board
    |> Repo.get!(id)
    |> Repo.preload(lists: {from(l in List, order_by: l.position), tasks: tasks_query})
  end
end
