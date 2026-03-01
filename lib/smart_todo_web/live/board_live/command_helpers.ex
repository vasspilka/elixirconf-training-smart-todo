defmodule SmartTodoWeb.BoardLive.CommandHelpers do
  @moduledoc """
  Shared assigns, event handlers, and handle_info callbacks
  for the chat sidepanel and command input components.

  Usage: `use SmartTodoWeb.BoardLive.CommandHelpers`
  """

  defmacro __using__(_opts) do
    quote do
      import SmartTodoWeb.BoardLive.CommandHelpers,
        only: [assign_command_helpers: 1, reload_board: 1]

      # --- Chat & command input events ---

      def handle_event("toggle_chat_panel", _params, socket) do
        {:noreply,
         Phoenix.Component.assign(socket, :chat_panel_open, !socket.assigns.chat_panel_open)}
      end

      def handle_event("toggle_command_input", _params, socket) do
        {:noreply,
         Phoenix.Component.assign(
           socket,
           :command_input_open,
           !socket.assigns.command_input_open
         )}
      end

      def handle_event("close_command_input", _params, socket) do
        {:noreply, Phoenix.Component.assign(socket, :command_input_open, false)}
      end
    end
  end

  import Phoenix.Component, only: [assign: 3]

  def assign_command_helpers(socket) do
    socket
    |> assign(:chat_panel_open, false)
    |> assign(:chat_messages, [])
    |> assign(:command_input_open, false)
    |> assign(:available_commands, default_commands())
    |> assign(:loading, false)
    |> assign(:preview_cards, [])
  end

  ## TODO: Implement this
  # Replace the stub response with an actual LLM call.
  # Phase 5: integrate with the chat agent and stream responses.
  def handle_chat_message(socket, text) do
    user_message = %{role: :user, content: text}

    stub = %{
      role: :assistant,
      content: "I'm not connected to an LLM yet. We'll wire this up soon!"
    }

    assign(socket, :chat_messages, socket.assigns.chat_messages ++ [user_message, stub])
  end

  ## TODO: Implement this
  # Parse the command text with the LLM and execute the appropriate action.
  # Phase 1: parse into card structs and assign to :preview_cards.
  # Phase 2: use LLM tools to mutate the board directly.
  def handle_execute_command(socket, _text) do
    assign(socket, :command_input_open, false)
  end

  def reload_board(socket) do
    board = SmartTodo.Todos.get_board_with_data!(socket.assigns.board.id)
    assign(socket, :board, board)
  end

  def handle_add_preview_cards(socket, selected_cards) do
    board = socket.assigns.board
    default_list = Enum.at(board.lists, 0)

    results =
      Enum.map(selected_cards, fn card_attrs ->
        list_id =
          Map.get(card_attrs, :list_id) || Map.get(card_attrs, "list_id") || default_list.id

        list = Enum.find(board.lists, &(&1.id == list_id)) || default_list
        position = length(list.cards)

        attrs =
          card_attrs
          |> Map.new(fn {k, v} -> {to_string(k), v} end)
          |> Map.merge(%{
            "board_id" => board.id,
            "list_id" => list_id,
            "position" => position
          })

        SmartTodo.Todos.create_card(attrs)
      end)

    failed = Enum.count(results, &match?({:error, _}, &1))

    socket = assign(socket, :preview_cards, [])
    socket = reload_board(socket)

    if failed > 0 do
      Phoenix.LiveView.put_flash(socket, :error, "#{failed} card(s) failed to create")
    else
      socket
    end
  end

  defp default_commands do
    [
      %{name: "Create card", description: "Add a new card to a list", icon: "hero-plus-circle"},
      %{
        name: "Move card",
        description: "Move a card to another list",
        icon: "hero-arrow-right-circle"
      },
      %{name: "Set priority", description: "Change a card's priority", icon: "hero-flag"},
      %{name: "Add label", description: "Add a label to a card", icon: "hero-tag"},
      %{name: "Archive card", description: "Archive a card", icon: "hero-archive-box"},
      %{name: "Ask AI", description: "Ask AI for help with your board", icon: "hero-sparkles"}
    ]
  end
end
