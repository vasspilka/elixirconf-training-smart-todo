defmodule SmartTodo.LLM do
  @moduledoc """
  Interface for LLM-powered features.
  Phase 1: Parse natural language into structured card data.
  """

  alias LangChain.ChatModels.ChatGoogleAI
  alias LangChain.Chains.LLMChain
  alias LangChain.Message

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
    system_prompt = """
    You are a task management assistant. Parse the user's text into one or more cards for a Kanban board.

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

  defp board_context_prompt(context) when map_size(context) == 0, do: ""

  defp board_context_prompt(context) do
    lists = Map.get(context, :lists, [])
    board_name = Map.get(context, :board_name, "Board")
    "Current board: #{board_name}\nExisting lists: #{Enum.join(lists, ", ")}"
  end
end
