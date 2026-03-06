defmodule SmartTodo.EvalHelpers do
  @moduledoc """
  Test helpers for LLM evaluations.
  Provides reusable board setups and context builders for trajectory testing.
  """

  alias SmartTodo.Todos

  @doc """
  Creates a fully populated board with multiple lists and cards for evaluation.

  Returns a map with board, lists, and cards ready for testing.
  """
  def create_eval_board do
    {:ok, board} = Todos.create_board(%{title: "Sprint Board", position: 0})

    {:ok, backlog} = Todos.create_list(%{title: "Backlog", board_id: board.id, position: 0})
    {:ok, todo} = Todos.create_list(%{title: "To Do", board_id: board.id, position: 1})

    {:ok, in_progress} =
      Todos.create_list(%{title: "In Progress", board_id: board.id, position: 2})

    {:ok, done} = Todos.create_list(%{title: "Done", board_id: board.id, position: 3})

    {:ok, login_card} =
      Todos.create_card(%{
        title: "Fix login bug",
        description: "Users can't log in with SSO",
        board_id: board.id,
        list_id: todo.id,
        position: 0,
        priority: "urgent",
        labels: ["bug", "auth"]
      })

    {:ok, api_card} =
      Todos.create_card(%{
        title: "Build REST API",
        description: "Implement CRUD endpoints for users",
        board_id: board.id,
        list_id: in_progress.id,
        position: 0,
        priority: "high",
        labels: ["backend", "api"]
      })

    {:ok, docs_card} =
      Todos.create_card(%{
        title: "Write documentation",
        description: "Add API docs and README",
        board_id: board.id,
        list_id: todo.id,
        position: 1,
        priority: "low",
        labels: ["docs"]
      })

    {:ok, deploy_card} =
      Todos.create_card(%{
        title: "Set up CI/CD pipeline",
        description: "Configure GitHub Actions for testing and deployment",
        board_id: board.id,
        list_id: backlog.id,
        position: 0,
        priority: "medium",
        labels: ["devops"]
      })

    {:ok, review_card} =
      Todos.create_card(%{
        title: "Code review for payments",
        description: "Review the payment integration PR",
        board_id: board.id,
        list_id: done.id,
        position: 0,
        priority: "high",
        labels: ["review"]
      })

    %{
      board: board,
      lists: %{
        backlog: backlog,
        todo: todo,
        in_progress: in_progress,
        done: done
      },
      cards: %{
        login: login_card,
        api: api_card,
        docs: docs_card,
        deploy: deploy_card,
        review: review_card
      }
    }
  end

  @doc """
  Builds the board context map expected by `SmartTodo.LLM` functions.
  """
  def build_board_context(board_id) do
    board = Todos.get_board_with_data!(board_id)

    %{
      board_name: board.title,
      lists:
        Enum.map(board.lists, fn list ->
          %{
            title: list.title,
            cards:
              Enum.map(list.cards, fn card ->
                %{
                  title: card.title,
                  priority: card.priority,
                  labels: card.labels || [],
                  due_date: card.due_date
                }
              end)
          }
        end)
    }
  end
end
