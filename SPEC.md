# SmartTodo — A smart task manager

We are starting with the foundations of a Trello like board where you can manually manage boards, lists and cards. 
Our goal is to extend these foundations to create a smart task manager that can understand natural language and process arbitrary text.

At the end we will have an application where you can manage your tasks not only manually but also though natural language, you can give it full product requirements and it will turn it into prioritized tasks, 
give it a summary of changes that it needs to do (for example provide a team update and let it modify the board accordingly), search and discuss your current tasks, and finally a goal oriented research agent that can manage the board for us.

---

## At a Glance

| Phase | What we build | Capabilities |
|-------|--------------|-------------------|
| 1 | Setup LLM calling + structured output | Get structured data from LLM |
| 2 | LLM tools | Allow our LLM to become an agent making changes to our boards |
| 3 | Evaluations | We ensure our model is capable of doing the things we need |
| 4 | Embeddings | Search cards by meaning, spot duplicates |
| 5 | Chat + streaming | A board-aware assistant that streams replies |
| 6 | Research agent | Research the web to create or update tasks |

--- START ---

## Phase 1 — A Command Parser

### 1.1 First LLM call
Wire up [LangChain](https://github.com/brainlid/langchain), configure the provider, create a function to interface with the LLM make a live test for it.

### 1.2 Structured responses
Teach the LLM to reply with JSON that matches our Card schema (title, description, priority, labels, due_date). Write test to feed it *"Add three tasks for CI: lint, test, deploy"* and get back a clean array of card objects.

### 1.3 Preview & accept
Wire it up with our preview and add where users can toggle individual cards on/off, then hit "Add Selected". With this we can do some dogfooding and give this spec document to our command parser to create all tasks we'll work on.

---

## Phase 2 — Let the LLM act

### 2.1 Basic tools
Give the LLM tools to mutate the board directly:

- `create_list`
- `create_card`, `move_card`, `update_card`, `archive_card`

`update_card` covers setting priority, due date, and labels in a single tool.

User says *"Move the login task to Done"*, the LLM picks the right tool, the board updates live.

### 2.2 Intent detection
Before executing, a lightweight LLM call figures out what the user *wants* to do and shows it in the Command Palette — It will reply with a list of tool names (enums) that are expected to be used, for example:

```
["create_list", "create_card"]
```

In the case the users just want to create cards we will use our preview and insert flow to add the cards (from Phase 1). Otherwise we will give the LLM direct access to the tools.

---

## Phase 3 — Evaluations

We have already made some live tests, we will now continue that trend writing some better ones. Using a few prepared prompts we will assert that they behave as we expect them to using the Langchain.Trajectory module.

- *"Move all urgent cards to In Progress"* → verify they moved
- *"Archive completed tasks"* → verify they're archived
- Measure intent detector accuracy against known (input, expected_actions) pairs

Test helpers and foundations are pre-built so we can focus on writing and running evals in class.

--- LUNCH BREAK ---

## Phase 4 — Embeddings

### 4.1 Setup and embeddings client

Add PGVector support — install the extension, add a `vector(768)` embedding field to cards.

Build `SmartTodo.Embeddings.Client` that converts a list of strings into embeddings (can use Google or other provider).

### 4.2 Indexer & Semantic search

Build the embeddings context module `SmartTodo.Embeddings` implementing `index/0` and `search/1`:

**`index/0`** — Finds all cards without an embedding, builds a text representation from their fields (title, description, labels, priority), generates vectors via the client, and bulk-updates them.

**`search/1`** — Takes a search prompt, embeds it, and queries cards by cosine similarity. Returns the top-N closest matches with their scores.

By the end we can call queries like `search("authentication")` to find cards about *"login"*, *"OAuth"*, *"sign-in"* ranked by relevance.

### 4.3 Deduplication (Bonus)
Add a `find_duplicates(board_id)` function to the embeddings context and add it as a tool to the Command parser.
Compare card embeddings, surface groups of similar cards. User decides what to merge or archive.

--- BREAK 1 ---

## Phase 5 — Chat with streaming

### 5.1 Conversation state & clear button
Set up the chat panel to maintain a proper conversation with the LLM. You can use the `LangChain.Message` response from the chain as the LLM response. Prime the conversation with a system message containing board context (board name, lists, card counts).

### 5.2 Streaming & markdown
Stream assistant responses token-by-token instead of waiting for the full reply. Render assistant messages as markdown (e.g. using `MDEx`) so code blocks, lists, and bold text display correctly. While streaming, show a subtle indicator and disable input to prevent sending mid-stream.

### 5.3 Integrate with semantic search and tools
Give the chat agent access to the board mutation tools from Phase 2 and a `search_cards` tool backed by Phase 4's semantic search. After any mutation, reload the board so the Kanban view updates in real time. The assistant should handle both questions (*"What urgent tasks do we have?"*) and commands (*"Move all done cards to archived"*) within the same conversation.

--- BREAK 2 ---

## Phase 6 — Research agent

### 6.1 Build an autonomous Research & Manage agent
A 3-step loop: **Plan → Research & Evaluate → Act**.

The Research agent will start by looking at it's prompt and exploring the existing boards to plan what needs to be done, then it will do web research and evaluate what tasks need to be created, it will then use the tools to create/update the board lists and cards.

User types "Create a plan for Kubernetes deployment". The agent searches the web, extracts findings, and presents them as card previews (reusing the Phase 1.3 flow). User reviews and accepts.

### 6.2 Recrusive loop and automatic toolcalling

Give the agent full autonomy using tools directly and the ability to loop through it's goal multiple times so that it can make continous improvements.

### 6.3 Agent as tool for chat panel (Bonus)

Allow the chat panel to access the research agent via "agent as a tool".
