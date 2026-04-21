# SmartTodo — Build a smart task manager

## Workshop summary

In this workshop, we will extend an existing Trello-like task manager with AI features.

What already works:
- boards
- lists
- cards

What we add in class:
- natural-language task creation
- tool-based board updates
- evaluation tests for reliability
- semantic search
- chat
- a research agent

You are **not** building the entire app from scratch. The board app already exists, and some helper code is already prepared.

## How to use this spec

- Work through the phases in order
- Focus on the **core path** first: Phases 1–4
- Treat Phases 5–6 as advanced if time is tight
- Skip bonus items unless you are comfortably ahead

## Quick glossary

- **Tool** — a function the LLM can call to change or inspect the board
- **Preview flow** — generate cards first, review them, then add the selected ones
- **Intent detection** — predict what kind of action the user is asking for
- **Semantic search** — search by meaning, not only by exact words
- **Evaluation test** — a repeatable prompt-based check for model behavior
- **Streaming** — show the assistant response as it is being generated

---

## At a glance

| Phase | What we build | Main outcome |
|-------|--------------|-------------------|
| 1 | LLM calling + structured output | Turn text into task card data |
| 2 | LLM tools + intent detection | Let the LLM modify the board safely |
| 3 | Evaluations | Verify the model does what we expect |
| 4 | Embeddings | Search cards by meaning |
| 5 | Chat + streaming | Build a board-aware assistant |
| 6 | Research agent | Research a topic and turn findings into tasks |

## Agenda mapping

This spec also follows the workshop day:

| Time | Focus |
|------|-------|
| 09:00–10:30 | Phase 1 foundations: first LLM call, structured output, preview flow |
| 10:30–11:00 | Tea and Coffee Break |
| 11:00–13:00 | Phase 2 and Phase 3: tools, intent detection, evaluation tests |
| 13:00–14:00 | Lunch |
| 14:00–15:00 | Phase 4: embeddings and semantic search |
| 15:00–15:30 | Tea and Coffee Break |
| 15:30–16:30 | Phase 5: chat and streaming |
| 16:30–17:00 | Phase 6: research agent overview and implementation |

---

## What success looks like by the end of the day

Minimum successful outcome:
- users can turn text into cards
- users can update the board with natural language
- core AI behavior is covered by evaluation tests
- cards can be searched semantically

Advanced outcome:
- a streaming chat assistant works against the board
- a research flow can propose new tasks for review

---

## Phase 1 — A command parser

### Goal
Teach the app to turn natural language into structured task data.

### Build

#### 1.1 First LLM call
Wire up [LangChain](https://github.com/brainlid/langchain), configure the provider, and create a small function that sends a prompt to the LLM and returns a response.

Also add a live test for it.

**Done when:**
- [ ] the app can successfully call the LLM
- [ ] you have one function that acts as your LLM entry point
- [ ] a live test confirms the connection works

#### 1.2 Structured responses
Teach the LLM to reply with JSON that matches our Card schema:
- `title`
- `description`
- `priority`
- `labels`
- `due_date`

Write a test that sends:

> "Add three tasks for CI: lint, test, deploy"

and gets back a clean array of card objects.

**Done when:**
- [ ] the model returns structured card-like data
- [ ] the output shape matches the Card fields we care about
- [ ] the CI example passes reliably in a test

#### 1.3 Preview and accept
Connect the parser to the preview flow so users can:
- generate candidate cards
- toggle individual cards on or off
- click **Add Selected** to insert only the chosen ones

This lets us try the system on our own workshop spec by feeding this document into the app and generating the tasks we will work on.

**Done when:**
- [ ] users can paste a request and get card previews
- [ ] users can exclude unwanted generated cards
- [ ] only selected cards are created on the board

**Example behavior:**
- User enters a product requirement
- App shows multiple proposed cards
- User deselects a few cards
- App creates only the remaining cards

### Checkpoint
By the end of Phase 1, you should be able to paste a natural-language request and create task cards from it through a preview flow.

---

## Phase 2 — Let the LLM act

### Goal
Allow the LLM to modify the board, not just suggest new cards.

### Build

#### 2.1 Basic tools
Give the LLM tools to mutate the board directly:
- `create_list`
- `create_card`
- `move_card`
- `update_card`
- `archive_card`

`update_card` should cover changes like:
- priority
- due date
- labels

**Example behavior:**
- User says: "Move the login task to Done"
- The LLM picks the right tool
- The board updates live

**Done when:**
- [ ] the LLM can choose and call the right tool
- [ ] board changes are reflected in the UI
- [ ] the basic board actions work from natural language

#### 2.2 Intent detection
Before executing actions, make a lightweight LLM call that decides what kind of request the user is making.

It should return a list of expected tool names, for example:

```json
["create_list", "create_card"]
```

Use this result to decide how to handle the request:
- if the user mainly wants to **create cards**, use the **preview and accept** flow from Phase 1
- otherwise, give the LLM direct access to the board tools

This helps us stay safer and more predictable.

**Done when:**
- [ ] the app can classify likely actions before execution
- [ ] card creation requests go through preview first
- [ ] board mutation requests can execute through tools

### Checkpoint
By the end of Phase 2, you should be able to type commands like:
- "Move the login task to Done"
- "Add a list for deployment"
- "Mark onboarding as high priority"

and see the board update correctly.

---

## Phase 3 — Evaluations

### Goal
Check whether the model behavior is actually good enough.

### Build
We already created some tests against a real model. Now we will go further and add better evaluation coverage using prepared prompts and `LangChain.Trajectory`.

Suggested evaluation cases:
- "Move all urgent cards to In Progress" → verify they moved
- "Archive completed tasks" → verify they were archived
- measure intent detector accuracy against known `(input, expected_actions)` pairs

Test helpers and foundations are pre-built so we can focus on writing and running evaluation tests in class.

**Done when:**
- [ ] you have repeatable evaluation cases for core workflows
- [ ] you can verify board mutations from model-driven actions
- [ ] you can measure whether intent detection is correct on known examples

### Checkpoint
By the end of Phase 3, you should have automated confidence that the AI behavior works for the most important board actions.

---

## Phase 4 — Embeddings

### Goal
Make cards searchable by meaning instead of exact wording.

### Build

#### 4.1 Setup and embeddings client
Add PGVector support:
- install the extension
- add a `vector(768)` embedding field to cards

Create `SmartTodo.Embeddings.Client` that converts a list of strings into embeddings using a provider such as Google or another supported provider.

**Done when:**
- [ ] cards can store embeddings
- [ ] you can request embeddings for text input through a dedicated client module

#### 4.2 Indexer and semantic search
Build the `SmartTodo.Embeddings` context with:
- `index/0`
- `search/1`

**`index/0`** should:
- find cards without embeddings
- build a text representation from card fields such as title, description, labels, and priority
- generate embeddings
- bulk update the records

**`search/1`** should:
- take a search query
- embed the query
- search cards by cosine similarity
- return the top matching cards with scores

**Example behavior:**
Calling:

```elixir
search("authentication")
```

should be able to find cards about:
- login
- OAuth
- sign-in

ranked by relevance.

**Done when:**
- [ ] missing embeddings can be generated and stored
- [ ] semantic search returns relevant results
- [ ] similar concepts can match even without exact keyword overlap

#### 4.3 Deduplication (Bonus)
Add:
- `find_duplicates(board_id)`

Then expose it as a tool to the command parser.

This should compare card embeddings and surface groups of similar cards so the user can decide what to merge or archive.

### Checkpoint
By the end of Phase 4, the app should support semantic card search.

---

## Phase 5 — Chat with streaming

### Goal
Add a board-aware assistant that can answer questions and perform actions in conversation.

### Build

#### 5.1 Conversation state and clear button
Set up the chat panel so it maintains conversation state with the LLM.

You can use the `LangChain.Message` response from the chain as the stored LLM response.

Prime the conversation with a system message that includes board context, such as:
- board name
- lists
- card counts

**Done when:**
- [ ] chat keeps conversational history
- [ ] the assistant has enough board context to respond helpfully
- [ ] the user can clear the conversation

#### 5.2 Streaming and markdown
Stream assistant responses token-by-token instead of waiting for the full response.

Render assistant messages as markdown, for example using `MDEx`, so that code blocks, lists, and bold text display nicely.

While streaming:
- show a subtle loading indicator
- disable input so the user does not submit mid-stream

**Done when:**
- [ ] replies stream progressively
- [ ] markdown is rendered correctly
- [ ] the UI clearly communicates when the assistant is busy

#### 5.3 Integrate with semantic search and tools
Give the chat agent access to:
- the board mutation tools from Phase 2
- a `search_cards` tool backed by Phase 4 semantic search

After any mutation, reload the board so the Kanban view updates in real time.

The assistant should support both:
- questions, like "What urgent tasks do we have?"
- commands, like "Move all done cards to archived"

within the same conversation.

**Done when:**
- [ ] the assistant can answer board questions
- [ ] the assistant can perform board actions
- [ ] semantic search can be used inside chat
- [ ] the board refreshes after changes

### Checkpoint
By the end of Phase 5, you should have a conversational assistant that understands the board and can both discuss and modify it.

---

## Phase 6 — Research agent

### Goal
Build an agent that can research a topic and turn findings into useful work on the board.

### Build

#### 6.1 Build a research agent
Start with a simple 3-step loop:
- **Plan**
- **Research and evaluate**
- **Act**

The agent should:
- inspect the prompt
- look at the existing board
- plan what work is needed
- do web research
- decide what tasks should be created or updated

A simple first version is:
- user enters a goal such as "Create a plan for Kubernetes deployment"
- agent researches the topic
- agent returns card previews
- user reviews and accepts them using the Phase 1.3 flow

**Done when:**
- [ ] the agent can turn a research goal into task suggestions
- [ ] findings are converted into card previews
- [ ] users can review results before insertion

#### 6.2 Recursive loop and automatic tool calling (Advanced / Bonus)
Give the agent more autonomy by letting it:
- use tools directly
- loop through its goal multiple times
- make continuous improvements to the board

This is more advanced and should be treated as optional unless there is time.

#### 6.3 Agent as a tool for chat panel (Bonus)
Allow the chat assistant to call the research agent as a tool.

### Checkpoint
By the end of Phase 6, a minimum successful version should be able to research a topic and propose useful tasks for the user to approve.

---

## Recommended focus if time is tight

It is completely okay if you do not reach every phase.

### Core workshop path
If time is limited, prioritize:
1. Phase 1
2. Phase 2
3. Phase 3
4. Phase 4

### Advanced work
Treat these as advanced if the class is moving quickly:
- Phase 5
- Phase 6
- duplicate detection
- autonomous looping behavior
- agent-as-tool integration

---

## Useful mental model

You can think about the system in layers:

- **LLM layer** — basic prompt/response calls
- **Command layer** — parse user intent and decide between preview vs direct actions
- **Tool layer** — mutate the board safely
- **Evaluation layer** — verify the system behaves correctly
- **Embeddings layer** — search by meaning
- **Chat layer** — support conversational interaction
- **Agent layer** — plan, research, and act toward a goal

This can help you decide where a piece of logic belongs.

---

