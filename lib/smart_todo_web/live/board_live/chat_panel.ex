defmodule SmartTodoWeb.BoardLive.ChatPanel do
  use SmartTodoWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="chat-panel"
      class={[
        "fixed top-0 right-0 h-full z-40 flex flex-col bg-base-200 border-l border-base-300 shadow-xl transition-transform duration-300",
        "w-80",
        if(@open, do: "translate-x-0", else: "translate-x-full")
      ]}
    >
      <div class="flex flex-col h-full">
        <%!-- Header --%>
        <div class="flex items-center justify-between p-3 border-b border-base-300">
          <h3 class="font-semibold text-sm flex items-center gap-2">
            <.icon name="hero-sparkles" class="size-4" /> AI Assistant
          </h3>
          <button class="btn btn-ghost btn-xs" phx-click="toggle_chat_panel">
            <.icon name="hero-x-mark" class="size-4" />
          </button>
        </div>

        <%!-- Messages --%>
        <div class="flex-1 overflow-y-auto p-3 space-y-3" id="chat-messages" phx-hook="ChatScroll">
          <div
            :if={@messages == []}
            class="flex flex-col items-center justify-center h-full text-base-content/40"
          >
            <.icon name="hero-chat-bubble-left-right" class="size-10 mb-2" />
            <p class="text-sm">No messages yet</p>
            <p class="text-xs">Ask the AI to help manage your board</p>
          </div>

          <div
            :for={msg <- @messages}
            class={["chat", if(msg.role == :user, do: "chat-end", else: "chat-start")]}
          >
            <div class={[
              "chat-bubble text-sm",
              if(msg.role == :user, do: "chat-bubble-primary", else: "chat-bubble-neutral")
            ]}>
              {msg.content}
            </div>
          </div>

          <div :if={@loading} class="chat chat-start">
            <div class="chat-bubble chat-bubble-neutral">
              <span class="loading loading-dots loading-sm"></span>
            </div>
          </div>
        </div>

        <%!-- Input --%>
        <div class="p-3 border-t border-base-300">
          <form
            phx-submit="send_chat_message"
            phx-target={@myself}
            phx-hook="ChatInput"
            id="chat-input-form"
            class="flex gap-2"
          >
            <input
              type="text"
              name="message"
              placeholder="Ask AI..."
              class="input input-sm input-bordered flex-1"
              autocomplete="off"
            />
            <button type="submit" class="btn btn-primary btn-sm">
              <.icon name="hero-paper-airplane" class="size-4" />
            </button>
          </form>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("send_chat_message", %{"message" => message}, socket) do
    text = String.trim(message)

    if text != "" do
      send(self(), {:chat_message, text})
    end

    {:noreply, socket}
  end
end
