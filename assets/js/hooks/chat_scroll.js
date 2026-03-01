// Auto-scrolls the chat messages container to the bottom
// whenever new messages are added or content is updated.
const ChatScroll = {
  mounted() {
    this.scrollToBottom()
  },
  updated() {
    this.scrollToBottom()
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

export default ChatScroll
