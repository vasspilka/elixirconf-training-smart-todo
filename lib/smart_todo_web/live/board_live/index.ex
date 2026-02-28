defmodule SmartTodoWeb.BoardLive.Index do
  use SmartTodoWeb, :live_view
  use SmartTodoWeb.BoardLive.CommandHelpers

  alias SmartTodo.Todos
  alias SmartTodo.Todos.Board
  alias SmartTodoWeb.BoardLive.CommandHelpers

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Boards")
     |> assign(:boards, Todos.list_boards())
     |> assign(:form, to_form(Todos.change_board(%Board{})))
     |> assign(:show_form, false)
     |> assign(:editing_board, nil)
     |> CommandHelpers.assign_command_helpers()}
  end

  @impl true
  def handle_event("new_board", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_board, nil)
     |> assign(:form, to_form(Todos.change_board(%Board{})))}
  end

  def handle_event("edit_board", %{"id" => id}, socket) do
    board = Todos.get_board!(id)

    {:noreply,
     socket
     |> assign(:show_form, true)
     |> assign(:editing_board, board)
     |> assign(:form, to_form(Todos.change_board(board)))}
  end

  def handle_event("cancel_form", _params, socket) do
    {:noreply, assign(socket, :show_form, false)}
  end

  def handle_event("validate_board", %{"board" => params}, socket) do
    board = socket.assigns.editing_board || %Board{}
    changeset = Todos.change_board(board, params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  def handle_event("save_board", %{"board" => params}, socket) do
    case socket.assigns.editing_board do
      nil -> create_board(socket, params)
      board -> update_board(socket, board, params)
    end
  end

  def handle_event("delete_board", %{"id" => id}, socket) do
    board = Todos.get_board!(id)
    {:ok, _} = Todos.delete_board(board)

    {:noreply,
     socket
     |> assign(:boards, Todos.list_boards())
     |> put_flash(:info, "Board deleted")}
  end

  # --- Handle info (from child components) ---

  @impl true
  def handle_info({:chat_message, text}, socket) do
    {:noreply, CommandHelpers.handle_chat_message(socket, text)}
  end

  def handle_info({:execute_command, _text}, socket) do
    {:noreply, CommandHelpers.handle_execute_command(socket)}
  end

  defp create_board(socket, params) do
    case Todos.create_board(params) do
      {:ok, _board} ->
        {:noreply,
         socket
         |> assign(:boards, Todos.list_boards())
         |> assign(:show_form, false)
         |> put_flash(:info, "Board created")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp update_board(socket, board, params) do
    case Todos.update_board(board, params) do
      {:ok, _board} ->
        {:noreply,
         socket
         |> assign(:boards, Todos.list_boards())
         |> assign(:show_form, false)
         |> put_flash(:info, "Board updated")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end
end
