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

- `create_board`, `switch_board`
- `create_list`
- `create_card`, `move_card`, `update_card`, `set_priority`, `add_label`, `archive_card`

User says *"Move the login task to Done"*, the LLM picks the right tool, the board updates live.

### 2.2 Intent detection
Before executing, a lightweight LLM call figures out what the user *wants* to do and shows it in the Command Palette — It will reply in structured JSON counting how many commands are expected to run for example:

%{
  create_board: 0,
  create_card: 2,
  move_card: 3,
  ..
}

These results will then be used to highlight the commands we expect to be run. 
Note that we should use a debounce of at least 1 second to avoid excessive LLM calls

---

## Phase 3 — Evaluations

We have already made some live tests, we will now continue that trend writing some better ones. Using a few prepared prompts we will assert that they behave as we expect them to using the Langchain.Trajectory module.

- *"Move all urgent cards to In Progress"* → verify they moved
- *"Archive completed tasks"* → verify they're archived
- Measure intent detector accuracy against known (input, expected_actions) pairs

Test helpers and foundations are pre-built so we can focus on writing and running evals in class.

--- LUNCH BREAK ---

## Phase 4 — Embeddings

### 4.1 Embeddings client
Build an `SmartTodo.Embeddings.Client` that gets embeddings from OpenAI based on a prompt, should accept a list of strings.

### 4.2 Indexer & Semantic search

Build the embeddings context module `SmartTodo.Embeddings` it should implement, `index()` and `search(prompt)` functions with semantic search.

For example:
Search *"authentication"* and find cards about *"login"*, *"OAuth"*, *"sign-in"*. Results ranked by similarity.

### 4.3 Deduplication
Add an `find_duplicates(board_id)` function to the embeddings context and add it as a tool the the Command parser.
Compare card embeddings, surface groups of similar cards. User decides what to merge or archive.

--- BREAK 1 ---

## Phase 5 — Chat with streaming

### 5.1 Chat panel
Integrate the existing chat UI with our LLM. We want to use streaming and markdown parsing for our responses.

### 5.2 Integrate with sematinc search and the other LLM tools
Provide the chat Agent with our previously registered tools as well as a search tasks tool so that it can become an assistant.

--- BREAK 2 ---

## Phase 6 — Research agent

### 6.1 Build an autonomous Research & Manage agent
A 3-step loop: **Plan → Research & Evaluate → Act**.

The Research agent will start by looking at it's prompt and exploring the existing boards to plan what needs to be done, then it will do web research and evaluate what should be added or updated, it will then use the tools to create/update the board lists and cards.

User types *"Research best practices for Kubernetes deployment"*. The agent searches the web, extracts findings, and presents them as card previews (reusing the Phase 1.3 flow). User reviews and accepts.

### 6.2 Recrusive loop

Give the agent full autonomy and the ability to loop through it's goal multiple times so that it can make continous improvements.

### 6.3 Bonus: Agent as tool for chat panel

Allow the chat panel to access the research agent via "agent as a tool".
