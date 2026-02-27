import Sortable from "sortablejs"

export default {
  mounted() {
    const hook = this

    this.sortable = Sortable.create(this.el, {
      group: "tasks",
      animation: 150,
      ghostClass: "sortable-ghost",
      dragClass: "sortable-drag",
      onEnd(evt) {
        const taskId = evt.item.dataset.taskId
        const toListId = evt.to.dataset.listId
        const orderedIds = Array.from(evt.to.children).map(
          (el) => el.dataset.taskId
        )

        hook.pushEvent("reorder_task", {
          task_id: taskId,
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
