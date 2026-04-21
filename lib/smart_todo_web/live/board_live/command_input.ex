defmodule SmartTodoWeb.BoardLive.CommandInput do
  use SmartTodoWeb, :live_component

  @debounce_ms 1000

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:input_value, fn -> "" end)
     |> assign_new(:detected_intents, fn -> %{} end)
     |> assign_new(:detecting, fn -> false end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="command-input-overlay"
      class="fixed inset-0 z-50 flex justify-center items-start pt-[20vh]"
      phx-window-keydown="close_command_input"
      phx-key="Escape"
    >
      <%!-- Backdrop --%>
      <div class="absolute inset-0 bg-black/50" phx-click="close_command_input"></div>

      <script :type={Phoenix.LiveView.ColocatedHook} name=".CommandTextarea">
        export default {
          mounted() {
            this.el.addEventListener("input", () => {
              this.resize()
              this.pushEventTo(this.el, "update_input", {command_text: this.el.value})
            })
            this.el.addEventListener("keydown", (e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault()
                const text = this.el.value.trim()
                if (text !== "") {
                  this.pushEventTo(this.el, "submit_command", {text: text})
                }
              }
            })
            this.resize()
          },
          updated() { this.resize() },
          resize() {
            this.el.style.height = "auto"
            this.el.style.height = this.el.scrollHeight + "px"
          }
        }
      </script>

      <%!-- Command palette --%>
      <div class="relative w-full max-w-lg bg-base-100 rounded-box shadow-2xl border border-base-300 overflow-hidden">
        <%!-- Input area --%>
        <div class="p-3">
          <textarea
            id="command-input-textarea"
            phx-hook=".CommandTextarea"
            phx-target={@myself}
            name="command_text"
            value={@input_value}
            placeholder="Type a command..."
            class="textarea textarea-bordered w-full resize-none leading-normal min-h-[2.5rem] max-h-48 overflow-y-auto"
            rows="1"
            autofocus
          />
        </div>

        <%!-- Suggestions --%>
        <div :if={@commands != []} class="border-t border-base-300 max-h-64 overflow-y-auto">
          <div
            :if={@detecting}
            class="flex items-center gap-2 text-xs text-base-content/50 px-3 py-1.5"
          >
            <span class="loading loading-dots loading-xs"></span>
            <span>Analyzing intent...</span>
          </div>
          <ul class="menu menu-sm p-2">
            <li :for={cmd <- display_commands(@commands, @input_value, @detected_intents)}>
              <button
                phx-click="select_command"
                phx-value-name={cmd.name}
                phx-target={@myself}
                class={["flex items-center gap-3", cmd[:matched] && "active"]}
              >
                <.icon name={cmd.icon} class="size-4 text-base-content/60" />
                <div>
                  <span class="font-medium text-sm">{cmd.name}</span>
                  <span class="text-xs text-base-content/50 ml-2">{cmd.description}</span>
                </div>
              </button>
            </li>
          </ul>
        </div>

        <%!-- Footer hints --%>
        <div class="border-t border-base-300 px-3 py-2 flex items-center gap-4 text-xs text-base-content/50">
          <span><kbd class="kbd kbd-xs">Enter</kbd> to submit</span>
          <span><kbd class="kbd kbd-xs">Shift+Enter</kbd> new line</span>
          <span><kbd class="kbd kbd-xs">Esc</kbd> to close</span>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("submit_command", %{"text" => text}, socket) do
    send(self(), {:execute_command, String.trim(text), socket.assigns.detected_intents})
    {:noreply, socket}
  end

  def handle_event("update_input", %{"command_text" => value}, socket) do
    # Cancel any pending debounce timer
    if socket.assigns[:debounce_ref], do: Process.cancel_timer(socket.assigns.debounce_ref)

    ref =
      if String.trim(value) != "" do
        Process.send_after(self(), {:detect_intent, value, socket.assigns.id}, @debounce_ms)
      end

    {:noreply,
     socket
     |> assign(:input_value, value)
     |> assign(:detecting, ref != nil)
     |> assign(:debounce_ref, ref)}
  end

  def handle_event("select_command", %{"name" => name}, socket) do
    {:noreply, assign(socket, :input_value, name <> " ")}
  end

  defp display_commands(commands, _input, detected_intents) when detected_intents != %{} do
    intent_tools = Enum.map(Map.keys(detected_intents), &to_string/1)

    commands
    |> Enum.filter(fn cmd -> to_string(cmd.tool) in intent_tools end)
    |> Enum.map(fn cmd -> Map.put(cmd, :matched, true) end)
  end

  defp display_commands(commands, input, _detected_intents) do
    filtered_commands(commands, input)
  end

  defp filtered_commands(commands, input) do
    query = String.downcase(String.trim(input))

    if query == "" do
      commands
    else
      Enum.filter(commands, fn cmd ->
        String.contains?(String.downcase(cmd.name), query) or
          String.contains?(String.downcase(cmd.description), query)
      end)
    end
  end
end
