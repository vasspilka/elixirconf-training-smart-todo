defmodule SmartTodo.LLM.Tools do
  @moduledoc """
  LangChain tool definitions that allow the LLM to mutate the board.
  Phase 2: create_list, create_card, move_card, update_card, archive_card.
  """

  alias LangChain.Function
  alias SmartTodo.Todos

  @doc """
  Returns all available tools for a given board_id.
  The board_id is passed as context to each tool function.
  """
  def all(board_id) do
    [
      list_cards(board_id),
      create_list(board_id),
      create_card(board_id),
      move_card(board_id),
      update_card(board_id),
      archive_card(board_id)
    ]
  end

  @doc "All board mutation tools plus semantic search. Used by the chat agent."
  def chat_tools(board_id) do
    all(board_id) ++ [search_cards(board_id)]
  end

  @doc "Tool names as strings, useful for intent detection."
  def tool_names, do: ~w(list_cards create_list create_card move_card update_card archive_card)

  defp list_cards(board_id) do
    Function.new!(%{
      name: "list_cards",
      description:
        "List all cards on the board, grouped by list. " <>
          "Use this to find card names before moving, updating, or archiving.",
      parameters_schema: %{
        type: "object",
        properties: %{},
        required: []
      },
      function: fn _args, _context ->
        board = Todos.get_board_with_data!(board_id)

        summary =
          Enum.map_join(board.lists, "\n", fn list ->
            cards =
              if list.cards == [],
                do: "(empty)",
                else: Enum.map_join(list.cards, ", ", & &1.title)

            "#{list.title}: #{cards}"
          end)

        {:ok, summary}
      end
    })
  end

  defp create_list(board_id) do
    Function.new!(%{
      name: "create_list",
      description: "Create a new list (column) on the board.",
      parameters_schema: %{
        type: "object",
        properties: %{
          title: %{type: "string", description: "The title of the new list"}
        },
        required: ["title"]
      },
      function: fn %{"title" => title}, _context ->
        board = Todos.get_board_with_data!(board_id)
        position = length(board.lists)

        case Todos.create_list(%{
               "title" => title,
               "board_id" => board_id,
               "position" => position
             }) do
          {:ok, list} -> {:ok, "Created list '#{list.title}'"}
          {:error, changeset} -> {:error, changeset_error(changeset)}
        end
      end
    })
  end

  defp create_card(board_id) do
    Function.new!(%{
      name: "create_card",
      description:
        "Create a new card in a list. Find the list by name first. " <>
          "Sets priority, labels, due_date, and description if provided.",
      parameters_schema: %{
        type: "object",
        properties: %{
          title: %{type: "string", description: "The card title"},
          list_name: %{
            type: "string",
            description: "The name of the list to add the card to"
          },
          description: %{type: "string", description: "Optional card description"},
          priority: %{
            type: "string",
            enum: ["low", "medium", "high", "urgent"],
            description: "Card priority level"
          },
          labels: %{
            type: "array",
            items: %{type: "string"},
            description: "Labels to attach to the card"
          },
          due_date: %{
            type: "string",
            description: "Due date in YYYY-MM-DD format"
          }
        },
        required: ["title", "list_name"]
      },
      function: fn args, _context ->
        list = Todos.get_list_by_title(board_id, args["list_name"])

        if list do
          cards_count = list |> Ecto.assoc(:cards) |> SmartTodo.Repo.aggregate(:count)

          attrs =
            %{
              "title" => args["title"],
              "board_id" => board_id,
              "list_id" => list.id,
              "position" => cards_count
            }
            |> maybe_put("description", args["description"])
            |> maybe_put("priority", args["priority"])
            |> maybe_put("labels", args["labels"])
            |> maybe_put("due_date", args["due_date"])

          case Todos.create_card(attrs) do
            {:ok, card} -> {:ok, "Created card '#{card.title}' in list '#{list.title}'"}
            {:error, changeset} -> {:error, changeset_error(changeset)}
          end
        else
          {:error, "List '#{args["list_name"]}' not found on this board"}
        end
      end
    })
  end

  defp move_card(board_id) do
    Function.new!(%{
      name: "move_card",
      description: "Move a card to a different list. Finds card and list by name.",
      parameters_schema: %{
        type: "object",
        properties: %{
          card_name: %{type: "string", description: "The name/title of the card to move"},
          to_list_name: %{type: "string", description: "The destination list name"}
        },
        required: ["card_name", "to_list_name"]
      },
      function: fn %{"card_name" => card_name, "to_list_name" => to_list_name}, _context ->
        card = Todos.get_card_by_title(board_id, card_name)
        list = Todos.get_list_by_title(board_id, to_list_name)

        cond do
          is_nil(card) ->
            {:error, "Card '#{card_name}' not found"}

          is_nil(list) ->
            {:error, "List '#{to_list_name}' not found"}

          true ->
            cards_count = list |> Ecto.assoc(:cards) |> SmartTodo.Repo.aggregate(:count)

            case Todos.move_card(card, list.id, cards_count) do
              {:ok, _card} -> {:ok, "Moved '#{card.title}' to '#{list.title}'"}
              {:error, changeset} -> {:error, changeset_error(changeset)}
            end
        end
      end
    })
  end

  defp update_card(board_id) do
    Function.new!(%{
      name: "update_card",
      description:
        "Update a card's properties: priority, due_date, labels, title, or description. " <>
          "Finds the card by its current name.",
      parameters_schema: %{
        type: "object",
        properties: %{
          card_name: %{type: "string", description: "The current name/title of the card"},
          title: %{type: "string", description: "New title (if renaming)"},
          description: %{type: "string", description: "New description"},
          priority: %{
            type: "string",
            enum: ["low", "medium", "high", "urgent"],
            description: "New priority level"
          },
          labels: %{
            type: "array",
            items: %{type: "string"},
            description: "New labels (replaces existing)"
          },
          due_date: %{
            type: "string",
            description: "New due date in YYYY-MM-DD format"
          }
        },
        required: ["card_name"]
      },
      function: fn args, _context ->
        card = Todos.get_card_by_title(board_id, args["card_name"])

        if card do
          attrs =
            %{}
            |> maybe_put("title", args["title"])
            |> maybe_put("description", args["description"])
            |> maybe_put("priority", args["priority"])
            |> maybe_put("labels", args["labels"])
            |> maybe_put("due_date", args["due_date"])

          case Todos.update_card(card, attrs) do
            {:ok, card} -> {:ok, "Updated card '#{card.title}'"}
            {:error, changeset} -> {:error, changeset_error(changeset)}
          end
        else
          {:error, "Card '#{args["card_name"]}' not found"}
        end
      end
    })
  end

  defp archive_card(board_id) do
    Function.new!(%{
      name: "archive_card",
      description: "Archive a card from the board. Finds the card by name.",
      parameters_schema: %{
        type: "object",
        properties: %{
          card_name: %{type: "string", description: "The name/title of the card to archive"}
        },
        required: ["card_name"]
      },
      function: fn %{"card_name" => card_name}, _context ->
        card = Todos.get_card_by_title(board_id, card_name)

        if card do
          case Todos.archive_card(card) do
            {:ok, _card} -> {:ok, "Archived card '#{card.title}'"}
            {:error, changeset} -> {:error, changeset_error(changeset)}
          end
        else
          {:error, "Card '#{card_name}' not found"}
        end
      end
    })
  end

  defp search_cards(board_id) do
    Function.new!(%{
      name: "search_cards",
      description:
        "Search for cards by meaning using semantic search. " <>
          "Finds cards related to a topic even if they use different words. " <>
          "Use this to answer questions about existing cards.",
      parameters_schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "The search query to find relevant cards"}
        },
        required: ["query"]
      },
      function: fn %{"query" => query}, _context ->
        case SmartTodo.Embeddings.search(query, board_id: board_id, limit: 5) do
          {:ok, []} ->
            {:ok, "No matching cards found."}

          {:ok, results} ->
            board = Todos.get_board_with_data!(board_id)
            list_map = Map.new(board.lists, fn l -> {l.id, l.title} end)

            summary =
              Enum.map_join(results, "\n", fn {card, score} ->
                list_name = Map.get(list_map, card.list_id, "Unknown")

                "- #{card.title} (similarity: #{Float.round(score, 2)}, list: \"#{list_name}\", priority: #{card.priority})"
              end)

            {:ok, summary}

          {:error, _} ->
            {:ok, "Semantic search is not available. Cards may not be indexed yet."}
        end
      end
    })
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp changeset_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
