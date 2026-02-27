import Sortable from "sortablejs"

export default {
  mounted() {
    const hook = this

    this.sortable = Sortable.create(this.el, {
      group: "cards",
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      onEnd(evt) {
        const cardId = evt.item.dataset.cardId
        const toListId = evt.to.dataset.listId
        const orderedIds = Array.from(evt.to.children).map(
          (el) => el.dataset.cardId
        )

        hook.pushEvent("reorder_card", {
          card_id: cardId,
          to_list_id: toListId,
          ordered_ids: orderedIds,
        })
      },
    })
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  },
}
