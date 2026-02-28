export default {
  mounted() {
    this.handleKeydown = (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault()
        this.pushEvent("toggle_command_input", {})
      }
    }

    window.addEventListener("keydown", this.handleKeydown)
  },

  destroyed() {
    window.removeEventListener("keydown", this.handleKeydown)
  },
}
