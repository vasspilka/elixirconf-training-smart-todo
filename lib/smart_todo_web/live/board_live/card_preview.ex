defmodule SmartTodoWeb.BoardLive.CardPreview do
  @moduledoc """
  Live component for previewing proposed cards before adding them to the board.
  Renders each proposed card with a checkbox so students can select which ones to create.
  """
  use SmartTodoWeb, :live_component

  @impl true
  def update(assigns, socket) do
    cards_with_selection =
      assigns.cards
      |> Enum.with_index()
      |> Enum.map(fn {card, idx} -> Map.put(card, :_index, idx) end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:cards_with_selection, cards_with_selection)
     |> assign(:selected, MapSet.new(Enum.map(cards_with_selection, & &1._index)))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="modal modal-open">
      <div class="modal-box max-w-2xl">
        <h3 class="font-bold text-lg mb-4 flex items-center gap-2">
          <.icon name="hero-sparkles" class="size-5" /> Proposed Cards
        </h3>

        <div class="space-y-3 max-h-96 overflow-y-auto">
          <div
            :for={card <- @cards_with_selection}
            class="card bg-base-200 shadow-sm"
          >
            <div class="card-body p-3">
              <div class="flex items-start gap-3">
                <input
                  type="checkbox"
                  class="checkbox checkbox-sm mt-1"
                  checked={MapSet.member?(@selected, card._index)}
                  phx-click="toggle_preview_card"
                  phx-value-index={card._index}
                  phx-target={@myself}
                />
                <div class="flex-1 min-w-0">
                  <p class="font-medium text-sm">{card_field(card, :title)}</p>
                  <p
                    :if={card_field(card, :description)}
                    class="text-xs text-base-content/60 mt-1 line-clamp-2"
                  >
                    {card_field(card, :description)}
                  </p>
                  <div class="flex flex-wrap gap-1 mt-2">
                    <span
                      :if={card_field(card, :priority)}
                      class={"badge badge-xs #{priority_badge_class(card_field(card, :priority))}"}
                    >
                      {card_field(card, :priority)}
                    </span>
                    <span
                      :if={card_field(card, :due_date)}
                      class="badge badge-xs badge-outline"
                    >
                      {card_field(card, :due_date)}
                    </span>
                    <span
                      :for={label <- card_field(card, :labels) || []}
                      class="badge badge-xs badge-neutral"
                    >
                      {label}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="modal-action">
          <button
            class="btn btn-primary btn-sm"
            phx-click="add_selected_cards"
            phx-target={@myself}
            disabled={MapSet.size(@selected) == 0}
          >
            Add Selected ({MapSet.size(@selected)})
          </button>
          <button
            class="btn btn-ghost btn-sm"
            phx-click="dismiss_preview"
            phx-target={@myself}
          >
            Dismiss
          </button>
        </div>
      </div>
      <div class="modal-backdrop" phx-click="dismiss_preview" phx-target={@myself}></div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_preview_card", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    selected =
      if MapSet.member?(socket.assigns.selected, index) do
        MapSet.delete(socket.assigns.selected, index)
      else
        MapSet.put(socket.assigns.selected, index)
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("add_selected_cards", _params, socket) do
    selected_cards =
      socket.assigns.cards_with_selection
      |> Enum.filter(&MapSet.member?(socket.assigns.selected, &1._index))
      |> Enum.map(&Map.delete(&1, :_index))

    send(self(), {:add_preview_cards, selected_cards})
    {:noreply, socket}
  end

  def handle_event("dismiss_preview", _params, socket) do
    send(self(), :dismiss_preview)
    {:noreply, socket}
  end

  defp card_field(card, key) do
    Map.get(card, key) || Map.get(card, to_string(key))
  end

  defp priority_badge_class(priority) do
    case to_string(priority) do
      "urgent" -> "badge-error"
      "high" -> "badge-warning"
      "medium" -> "badge-info"
      _ -> "badge-ghost"
    end
  end
end
