defmodule SmartTodoWeb.BoardLive.CommandHelpers do
  @moduledoc """
  Shared assigns, event handlers, and handle_info callbacks
  for the chat sidepanel and command input components.

  Usage: `use SmartTodoWeb.BoardLive.CommandHelpers`
  """

  defmacro __using__(_opts) do
    quote do
      import SmartTodoWeb.BoardLive.CommandHelpers, only: [assign_command_helpers: 1]

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
  end

  def handle_chat_message(socket, text) do
    message = %{role: :user, content: text}
    assign(socket, :chat_messages, socket.assigns.chat_messages ++ [message])
  end

  def handle_execute_command(socket) do
    assign(socket, :command_input_open, false)
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
