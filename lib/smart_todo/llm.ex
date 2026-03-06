defmodule SmartTodo.LLM do
  @moduledoc """
  Interface for LLM-powered features.
  Phase 1: Parse natural language into structured card data.
  Phase 2: Intent detection and tool-based command execution.
  """

  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Chains.LLMChain
  alias LangChain.Message
  alias SmartTodo.LLM.Tools

  @cards_schema %{
    "type" => "object",
    "properties" => %{
      "cards" => %{
        "type" => "array",
        "items" => %{
          "type" => "object",
          "properties" => %{
            "title" => %{"type" => "string"},
            "description" => %{"type" => "string"},
            "priority" => %{"type" => "string", "enum" => ["low", "medium", "high", "urgent"]},
            "labels" => %{"type" => "array", "items" => %{"type" => "string"}},
            "due_date" => %{"type" => "string", "description" => "YYYY-MM-DD format"}
          },
          "required" => ["title"]
        }
      }
    },
    "required" => ["cards"]
  }

  @doc """
  Returns a configured ChatGoogleAI model instance.
  """
  def chat_model(opts \\ %{}) do
    model = Application.get_env(:smart_todo, :llm_model, "gemini-3.1-flash-lite-preview")

    ChatGoogleAI.new!(%{
      model: model,
      temperature: Map.get(opts, :temperature, 0.2),
      stream: Map.get(opts, :stream, false),
      json_response: Map.get(opts, :json_response, false),
      json_schema: Map.get(opts, :json_schema, nil)
    })
  end

  @doc """
  Parses user text into a list of card attribute maps using the LLM.

  Returns `{:ok, [card_attrs]}` or `{:error, reason}`.

  Each card_attrs map has string keys: "title", "description", "priority",
  "labels", "due_date".
  """
  def parse_cards(text, board_context \\ %{}) do
    today = Date.utc_today() |> Date.to_iso8601()

    system_prompt = """
    You are a task management assistant. Parse the user's text into one or more cards for a Kanban board.
    Use the board context to assign appropriate list names and priorities.

    Today's date is #{today}.

    Extract the following for each card:
    - title (required): A short, clear title
    - description (optional): A brief description if enough context is provided
    - priority (optional): One of "low", "medium", "high", "urgent". Default to "medium" if not specified.
    - labels (optional): Relevant labels as an array of strings
    - due_date (optional): A date in YYYY-MM-DD format if mentioned

    #{board_context_prompt(board_context)}
    """

    model = chat_model(%{json_response: true, json_schema: @cards_schema})

    case %{llm: model, verbose: false}
         |> LLMChain.new!()
         |> LLMChain.add_message(Message.new_system!(system_prompt))
         |> LLMChain.add_message(Message.new_user!(text))
         |> LLMChain.run() do
      {:ok, chain} ->
        json =
          chain.last_message.content
          |> List.first()
          |> Map.get(:content)

        cards = json |> Jason.decode!() |> Map.get("cards", [])
        {:ok, cards}

      {:error, _chain, %LangChain.LangChainError{message: message}} ->
        {:error, message}
    end
  end

  @intent_schema %{
    "type" => "object",
    "properties" => %{
      "intents" => %{
        "type" => "array",
        "items" => %{
          "type" => "string",
          "enum" => Tools.tool_names()
        }
      }
    },
    "required" => ["intents"]
  }

  @doc """
  Detects the user's intent from their command text.

  Returns `{:ok, intents}` where intents is a list of tool name strings,
  or `{:error, reason}`.
  """
  def detect_intent(text, board_context \\ %{}) do
    system_prompt = """
    You are an intent detector for a Kanban board command input.
    The user has typed a command and you must predict which board tools they want to use.
    Return one entry per tool type that will be needed — do NOT repeat tools.

    Rules:
    - This is a task management app. If the user describes something they need to do, a reminder, or any task-like statement, that means create_card.
    - If the user pastes a document, spec, or long text, they want to create_card from it.
    - Do NOT interpret mentions of tool names inside the text as actions. Focus on what the user WANTS TO DO, not what the text talks about.
    - move_card: when the user implies a status change, e.g. "Mark X as done", "We finished task B", "X is in progress now".
    - update_card: when the user implies content changed, e.g. "Requirements changed for X, now we also need Y", "Add a due date to X".
    - archive_card: when the user wants to remove or discard a card, e.g. "We no longer need X", "Delete task Y".
    - create_list: when the user wants a new column/list on the board.
    - When in doubt, default to create_card.
    """

    model = chat_model(%{json_response: true, json_schema: @intent_schema})

    case %{llm: model, verbose: false}
         |> LLMChain.new!()
         |> LLMChain.add_message(Message.new_system!(system_prompt))
         |> LLMChain.add_message(Message.new_user!(text))
         |> LLMChain.run() do
      {:ok, chain} ->
        json =
          chain.last_message.content
          |> List.first()
          |> Map.get(:content)

        intents = json |> Jason.decode!() |> Map.get("intents", [])
        {:ok, intents}

      {:error, _chain, %LangChain.LangChainError{message: message}} ->
        {:error, message}
    end
  end

  @doc """
  Executes a user command by giving the LLM access to board-mutation tools.

  The LLM will call the appropriate tools based on the user's text.
  Returns `{:ok, response_text}` or `{:error, reason}`.
  """
  def execute_command(text, board_id, board_context \\ %{}) do
    today = Date.utc_today() |> Date.to_iso8601()

    system_prompt = """
    You are a task management assistant for a Kanban board application.
    You can create, move, update, and archive cards, as well as create lists.

    Today's date is #{today}.

    ## Current Board State
    #{board_context_prompt(board_context)}

    ## Instructions
    - Use the provided tools to fulfill the user's request.
    - When referring to cards or lists, match by name (case-insensitive).
    - After completing all actions, respond with a brief summary of what you did.
    - If you cannot find a card or list, explain what went wrong.
    """

    tools = Tools.all(board_id)
    model = chat_model()

    case %{llm: model, verbose: false}
         |> LLMChain.new!()
         |> LLMChain.add_tools(tools)
         |> LLMChain.add_message(Message.new_system!(system_prompt))
         |> LLMChain.add_message(Message.new_user!(text))
         |> LLMChain.run(mode: :while_needs_response) do
      {:ok, chain} ->
        response =
          case chain.last_message.content do
            content when is_binary(content) -> content
            [%{content: content} | _] -> content
            content when is_list(content) -> Enum.map_join(content, "\n", & &1)
            _ -> "Command executed successfully."
          end

        {:ok, response}

      {:error, _chain, %LangChain.LangChainError{message: message}} ->
        {:error, message}
    end
  end

  defp board_context_prompt(context) when map_size(context) == 0, do: ""

  defp board_context_prompt(context) do
    lists = Map.get(context, :lists, [])
    board_name = Map.get(context, :board_name, "Board")

    lists_info =
      Enum.map_join(lists, "\n", fn
        %{title: title, cards: cards} when is_list(cards) ->
          if cards == [] do
            "  List: \"#{title}\" (empty)"
          else
            cards_text =
              Enum.map_join(cards, "\n", fn
                %{title: card_title} = card ->
                  priority = Map.get(card, :priority, "medium")
                  labels = Map.get(card, :labels, [])
                  due_date = Map.get(card, :due_date)

                  labels_str = if labels != [], do: " [#{Enum.join(labels, ", ")}]", else: ""
                  due_str = if due_date, do: " (due: #{due_date})", else: ""

                  "    - #{card_title} (priority: #{priority})#{labels_str}#{due_str}"

                card_title when is_binary(card_title) ->
                  "    - #{card_title}"
              end)

            "  List: \"#{title}\"\n#{cards_text}"
          end

        title when is_binary(title) ->
          "  List: \"#{title}\""
      end)

    "Board: \"#{board_name}\"\n#{lists_info}"
  end
end
