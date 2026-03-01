export default {
  mounted() {
    this.el.addEventListener("submit", () => {
      const input = this.el.querySelector("input[name='message']")
      if (input) {
        setTimeout(() => { input.value = "" }, 0)
      }
    })
  }
}
