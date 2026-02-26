alias SmartTodo.Todos

{:ok, board} =
  Todos.create_board(%{title: "My Project", description: "A sample project board", position: 0})

{:ok, todo_list} = Todos.create_list(%{title: "To Do", position: 0, board_id: board.id})

{:ok, in_progress_list} =
  Todos.create_list(%{title: "In Progress", position: 1, board_id: board.id})

{:ok, done_list} = Todos.create_list(%{title: "Done", position: 2, board_id: board.id})

Todos.create_task(%{
  title: "Set up project structure",
  description: "Initialize the Phoenix project with LiveView",
  position: 0,
  priority: :high,
  labels: ["setup"],
  list_id: todo_list.id,
  board_id: board.id
})

Todos.create_task(%{
  title: "Design database schema",
  position: 1,
  priority: :urgent,
  labels: ["backend", "database"],
  list_id: todo_list.id,
  board_id: board.id
})

Todos.create_task(%{
  title: "Build board UI",
  description: "Create the main board view with drag and drop",
  position: 0,
  priority: :medium,
  labels: ["frontend"],
  list_id: in_progress_list.id,
  board_id: board.id
})

Todos.create_task(%{
  title: "Add authentication",
  position: 1,
  priority: :low,
  due_date: ~D[2026-03-15],
  labels: ["backend", "auth"],
  list_id: in_progress_list.id,
  board_id: board.id
})

Todos.create_task(%{
  title: "Write README",
  position: 0,
  priority: :low,
  labels: ["docs"],
  list_id: done_list.id,
  board_id: board.id
})
