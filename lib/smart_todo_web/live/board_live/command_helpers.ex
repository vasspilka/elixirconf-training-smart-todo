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

      def handle_event("clear_chat", _params, socket) do
        {:noreply,
         socket
         |> Phoenix.Component.assign(:chat_messages, [])
         |> Phoenix.Component.assign(:streaming, false)
         |> Phoenix.Component.assign(:streaming_content, "")}
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
    |> assign(:loading_text, "Processing command...")
    |> assign(:streaming, false)
    |> assign(:streaming_content, "")
    |> assign(:preview_cards, [])
  end

  def handle_chat_message(socket, text) do
    user_message = %{role: :user, content: text}
    messages = socket.assigns.chat_messages ++ [user_message]

    board = socket.assigns.board
    lv_pid = self()

    board_context = %{
      board_name: board.title,
      lists:
        Enum.map(board.lists, fn list ->
          %{
            title: list.title,
            cards:
              Enum.map(list.cards, fn card ->
                %{
                  title: card.title,
                  priority: card.priority,
                  labels: card.labels || [],
                  due_date: card.due_date
                }
              end)
          }
        end)
    }

    Task.start(fn ->
      result = SmartTodo.LLM.chat(messages, board.id, board_context, lv_pid)
      send(lv_pid, {:chat_complete, result})
    end)

    socket
    |> assign(:chat_messages, messages)
    |> assign(:streaming, true)
    |> assign(:streaming_content, "")
  end

  def handle_execute_command(socket, text, intents \\ %{}) do
    lv_pid = self()

    board = socket.assigns.board

    board_context = %{
      board_name: board.title,
      lists:
        Enum.map(board.lists, fn list ->
          %{
            title: list.title,
            cards:
              Enum.map(list.cards, fn card ->
                %{
                  title: card.title,
                  priority: card.priority,
                  labels: card.labels || [],
                  due_date: card.due_date
                }
              end)
          }
        end)
    }

    intent_list =
      case intents do
        map when is_map(map) -> Map.keys(map)
        list when is_list(list) -> list
        _ -> []
      end

    is_research? = has_research_intent?(intent_list)
    use_preview? = only_create_cards?(intent_list)

    loading_text =
      if is_research?, do: "Research agent is working...", else: "Processing command..."

    Task.start(fn ->
      cond do
        is_research? ->
          result =
            SmartTodo.LLM.ResearchAgent.run(text, board.id, board_context, mode: :preview)

          send(lv_pid, {:research_result, result})

        use_preview? ->
          result = SmartTodo.LLM.parse_cards(text, board_context)
          send(lv_pid, {:parsed_cards, result})

        true ->
          result = SmartTodo.LLM.execute_command(text, board.id, board_context)
          send(lv_pid, {:command_result, result})
      end
    end)

    socket
    |> assign(:command_input_open, false)
    |> assign(:loading, true)
    |> assign(:loading_text, loading_text)
  end

  defp has_research_intent?(intents) do
    Enum.any?(intents, &(&1 in ["research", :research]))
  end

  defp only_create_cards?(intents) do
    intents == [] or Enum.all?(intents, &(&1 in ["create_card", :create_card]))
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
      %{
        name: "Create list",
        description: "Add a new list to the board",
        icon: "hero-queue-list",
        tool: :create_list
      },
      %{
        name: "Create card",
        description: "Add a new card to a list",
        icon: "hero-plus-circle",
        tool: :create_card
      },
      %{
        name: "Move card",
        description: "Move a card to another list",
        icon: "hero-arrow-right-circle",
        tool: :move_card
      },
      %{
        name: "Update card",
        description: "Update a card's priority, due date, or labels",
        icon: "hero-pencil-square",
        tool: :update_card
      },
      %{
        name: "Archive card",
        description: "Archive a card from the board",
        icon: "hero-archive-box",
        tool: :archive_card
      },
      %{
        name: "Research",
        description: "Research a topic on the web and create tasks from findings",
        icon: "hero-globe-alt",
        tool: :research
      }
    ]
  end
end
