defmodule SmartTodoWeb.BoardLive.Show do
  use SmartTodoWeb, :live_view

  alias SmartTodo.Todos
  alias SmartTodo.Todos.{List, Task}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    board = Todos.get_board_with_data!(id)

    {:ok,
     socket
     |> assign(:page_title, board.title)
     |> assign(:board, board)
     |> assign(:adding_list, false)
     |> assign(:list_form, to_form(Todos.change_list(%List{}, %{board_id: board.id})))
     |> assign(:adding_task_to, nil)
     |> assign(:task_form, to_form(Todos.change_task(%Task{})))
     |> assign(:editing_list, nil)
     |> assign(:editing_task, nil)
     |> assign(:task_detail, nil)}
  end

  # --- List events ---

  @impl true
  def handle_event("show_add_list", _params, socket) do
    {:noreply, assign(socket, :adding_list, true)}
  end

  def handle_event("cancel_add_list", _params, socket) do
    {:noreply, assign(socket, :adding_list, false)}
  end

  def handle_event("add_list", %{"list" => params}, socket) do
    board = socket.assigns.board
    position = length(board.lists)

    params =
      Map.merge(params, %{"board_id" => to_string(board.id), "position" => to_string(position)})

    case Todos.create_list(params) do
      {:ok, _list} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:adding_list, false)}

      {:error, changeset} ->
        {:noreply, assign(socket, :list_form, to_form(changeset))}
    end
  end

  def handle_event("edit_list", %{"id" => id}, socket) do
    {:noreply, assign(socket, :editing_list, String.to_integer(id))}
  end

  def handle_event("cancel_edit_list", _params, socket) do
    {:noreply, assign(socket, :editing_list, nil)}
  end

  def handle_event("update_list", %{"id" => id, "list" => params}, socket) do
    list = Todos.get_list!(id)

    case Todos.update_list(list, params) do
      {:ok, _list} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:editing_list, nil)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_list", %{"id" => id}, socket) do
    list = Todos.get_list!(id)
    {:ok, _} = Todos.delete_list(list)
    {:noreply, reload_board(socket)}
  end

  # --- Task events ---

  def handle_event("show_add_task", %{"list-id" => list_id}, socket) do
    board = socket.assigns.board
    form = to_form(Todos.change_task(%Task{}, %{list_id: list_id, board_id: board.id}))

    {:noreply,
     socket
     |> assign(:adding_task_to, String.to_integer(list_id))
     |> assign(:task_form, form)}
  end

  def handle_event("cancel_add_task", _params, socket) do
    {:noreply, assign(socket, :adding_task_to, nil)}
  end

  def handle_event("add_task", %{"task" => params}, socket) do
    board = socket.assigns.board
    list_id = String.to_integer(params["list_id"])
    list = Enum.find(board.lists, &(&1.id == list_id))
    position = if list, do: length(list.tasks), else: 0

    params =
      Map.merge(params, %{
        "board_id" => to_string(board.id),
        "position" => to_string(position)
      })

    case Todos.create_task(params) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:adding_task_to, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :task_form, to_form(changeset))}
    end
  end

  def handle_event("edit_task", %{"id" => id}, socket) do
    task = Todos.get_task!(id)
    form = to_form(Todos.change_task(task))
    {:noreply, assign(socket, editing_task: task, task_form: form)}
  end

  def handle_event("cancel_edit_task", _params, socket) do
    {:noreply, assign(socket, :editing_task, nil)}
  end

  def handle_event("update_task", %{"task" => params}, socket) do
    task = socket.assigns.editing_task

    case Todos.update_task(task, params) do
      {:ok, _task} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:editing_task, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :task_form, to_form(changeset))}
    end
  end

  def handle_event("delete_task", %{"id" => id}, socket) do
    task = Todos.get_task!(id)
    {:ok, _} = Todos.delete_task(task)
    {:noreply, reload_board(socket)}
  end

  # --- Drag & drop ---

  def handle_event("reorder_task", params, socket) do
    %{"task_id" => task_id, "to_list_id" => to_list_id, "ordered_ids" => ordered_ids} = params

    ordered_ids = Enum.map(ordered_ids, &String.to_integer/1)
    to_list_id = String.to_integer(to_list_id)
    task_id = String.to_integer(task_id)

    task = Todos.get_task!(task_id)

    if task.list_id != to_list_id do
      Todos.update_task(task, %{list_id: to_list_id})
    end

    Todos.reorder_tasks(ordered_ids, to_list_id)

    {:noreply, reload_board(socket)}
  end

  defp reload_board(socket) do
    board = Todos.get_board_with_data!(socket.assigns.board.id)
    assign(socket, :board, board)
  end

  defp priority_badge_class(priority) do
    case priority do
      :urgent -> "badge-error"
      :high -> "badge-warning"
      :medium -> "badge-info"
      :low -> "badge-ghost"
    end
  end
end
