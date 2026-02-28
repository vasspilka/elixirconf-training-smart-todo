defmodule SmartTodoWeb.BoardLive.Show do
  use SmartTodoWeb, :live_view
  use SmartTodoWeb.BoardLive.CommandHelpers

  alias SmartTodo.Todos
  alias SmartTodo.Todos.{List, Card}
  alias SmartTodoWeb.BoardLive.CommandHelpers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    board = Todos.get_board_with_data!(id)

    {:ok,
     socket
     |> assign(:page_title, board.title)
     |> assign(:board, board)
     |> assign(:adding_list, false)
     |> assign(:list_form, to_form(Todos.change_list(%List{}, %{board_id: board.id})))
     |> assign(:adding_card_to, nil)
     |> assign(:card_form, to_form(Todos.change_card(%Card{})))
     |> assign(:editing_list, nil)
     |> assign(:editing_card, nil)
     |> assign(:card_detail, nil)
     |> CommandHelpers.assign_command_helpers()}
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

  # --- Card events ---

  def handle_event("show_add_card", %{"list-id" => list_id}, socket) do
    board = socket.assigns.board
    form = to_form(Todos.change_card(%Card{}, %{list_id: list_id, board_id: board.id}))

    {:noreply,
     socket
     |> assign(:adding_card_to, String.to_integer(list_id))
     |> assign(:card_form, form)}
  end

  def handle_event("cancel_add_card", _params, socket) do
    {:noreply, assign(socket, :adding_card_to, nil)}
  end

  def handle_event("add_card", %{"card" => params}, socket) do
    board = socket.assigns.board
    list_id = String.to_integer(params["list_id"])
    list = Enum.find(board.lists, &(&1.id == list_id))
    position = if list, do: length(list.cards), else: 0

    params =
      Map.merge(params, %{
        "board_id" => to_string(board.id),
        "position" => to_string(position)
      })

    case Todos.create_card(params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:adding_card_to, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :card_form, to_form(changeset))}
    end
  end

  def handle_event("edit_card", %{"id" => id}, socket) do
    card = Todos.get_card!(id)
    form = to_form(Todos.change_card(card))
    {:noreply, assign(socket, editing_card: card, card_form: form)}
  end

  def handle_event("cancel_edit_card", _params, socket) do
    {:noreply, assign(socket, :editing_card, nil)}
  end

  def handle_event("update_card", %{"card" => params}, socket) do
    card = socket.assigns.editing_card

    case Todos.update_card(card, params) do
      {:ok, _card} ->
        {:noreply,
         socket
         |> reload_board()
         |> assign(:editing_card, nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :card_form, to_form(changeset))}
    end
  end

  def handle_event("delete_card", %{"id" => id}, socket) do
    card = Todos.get_card!(id)
    {:ok, _} = Todos.delete_card(card)
    {:noreply, reload_board(socket)}
  end

  # --- Drag & drop ---

  def handle_event("reorder_card", params, socket) do
    %{"card_id" => card_id, "to_list_id" => to_list_id, "ordered_ids" => ordered_ids} = params

    ordered_ids = Enum.map(ordered_ids, &String.to_integer/1)
    to_list_id = String.to_integer(to_list_id)
    card_id = String.to_integer(card_id)

    card = Todos.get_card!(card_id)

    if card.list_id != to_list_id do
      Todos.update_card(card, %{list_id: to_list_id})
    end

    Todos.reorder_cards(ordered_ids, to_list_id)

    {:noreply, reload_board(socket)}
  end

  # --- Handle info (from child components) ---

  @impl true
  def handle_info({:chat_message, text}, socket) do
    {:noreply, CommandHelpers.handle_chat_message(socket, text)}
  end

  def handle_info({:execute_command, _text}, socket) do
    {:noreply, CommandHelpers.handle_execute_command(socket)}
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
