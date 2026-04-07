defmodule SmartTodo.LLM.ResearchAgent do
  @moduledoc """
  Research agent that follows a Plan -> Research & Evaluate -> Act loop.

  Phase 6.1: In `:preview` mode, researches a topic and returns findings text
  that is then parsed into card proposals for user review.

  Phase 6.2: In `:autonomous` mode, has full board tool access and creates/updates
  cards directly with recursive tool calling.
  """

  alias LangChain.Chains.LLMChain
  alias LangChain.Function
  alias LangChain.Message
  alias SmartTodo.LLM
  alias SmartTodo.LLM.Tools

  @doc """
  Runs the research agent.

  ## Options
    - `:mode` — `:preview` (default) or `:autonomous`
    - `:lv_pid` — LiveView process to stream deltas to

  Returns `{:ok, response_text}` or `{:error, reason}`.
  """
  def run(prompt, board_id, board_context, opts \\ []) do
    mode = Keyword.get(opts, :mode, :preview)
    lv_pid = Keyword.get(opts, :lv_pid)

    system_prompt = build_system_prompt(mode, board_context)
    tools = build_tools(mode, board_id)
    model = LLM.chat_model(%{stream: lv_pid != nil})

    chain =
      %{llm: model, verbose: false}
      |> LLMChain.new!()
      |> LLMChain.add_tools(tools)
      |> LLMChain.add_message(Message.new_system!(system_prompt))
      |> LLMChain.add_message(Message.new_user!(prompt))
      |> maybe_add_callback(lv_pid)

    case LLMChain.run(chain, mode: :while_needs_response) do
      {:ok, updated_chain} ->
        {:ok, extract_response(updated_chain.last_message)}

      {:error, _chain, %LangChain.LangChainError{message: message}} ->
        {:error, message}
    end
  end

  # --- System prompt ---

  defp build_system_prompt(mode, board_context) do
    today = Date.utc_today() |> Date.to_iso8601()

    """
    You are a research agent for SmartTodo, a Kanban board application.

    Follow this 3-step process:
    1. **Plan**: Analyze the user's request and the current board state. Determine what needs to be researched.
    2. **Research & Evaluate**: Use web_search to find information and read_webpage to get details from relevant pages. Evaluate your findings critically.
    3. **Act**: #{act_instruction(mode)}

    Today's date is #{today}.

    ## Current Board State
    #{LLM.board_context_prompt(board_context)}

    ## Guidelines
    - Search for multiple aspects of the topic to build comprehensive understanding
    - Read the most relevant pages for detailed information
    - #{mode_instruction(mode)}
    - Provide a clear summary of your research and actions at the end
    """
  end

  defp act_instruction(:preview) do
    """
    Based on your research, propose specific tasks that should be created on the board.
    For each proposed task, include:
    - A clear, actionable title
    - A description with details from your research
    - An appropriate priority (low/medium/high/urgent)
    - Relevant labels

    Structure your final response as a clear list of proposed tasks with all details.
    """
  end

  defp act_instruction(:autonomous) do
    """
    Based on your research, use the board tools to create lists and cards directly.
    Organize tasks logically into appropriate lists. Set priorities, descriptions, and labels.
    You can make multiple passes — create cards, then refine them with updates.
    """
  end

  defp mode_instruction(:preview) do
    "You are in PREVIEW mode: research and propose cards in your response. Do NOT create cards directly — just describe the tasks you recommend."
  end

  defp mode_instruction(:autonomous) do
    "You are in AUTONOMOUS mode: research and then create/update cards directly using board tools. You can loop through multiple rounds of research and action."
  end

  # --- Tool building ---

  defp build_tools(:preview, board_id) do
    [web_search(), read_webpage()] ++ Tools.board_read_tools(board_id)
  end

  defp build_tools(:autonomous, board_id) do
    [web_search(), read_webpage()] ++ Tools.agent_tools(board_id)
  end

  defp maybe_add_callback(chain, nil), do: chain

  defp maybe_add_callback(chain, lv_pid) do
    handler = %{
      on_llm_new_delta: fn _model, deltas ->
        Enum.each(List.wrap(deltas), fn delta ->
          case delta do
            %{content: %{type: :text, content: text}} when is_binary(text) and text != "" ->
              send(lv_pid, {:chat_delta, text})

            %{content: content} when is_binary(content) and content != "" ->
              send(lv_pid, {:chat_delta, content})

            _ ->
              :ok
          end
        end)
      end
    }

    LLMChain.add_callback(chain, handler)
  end

  # --- Research tools ---

  defp web_search do
    Function.new!(%{
      name: "web_search",
      description:
        "Search the web for information on a topic. " <>
          "Returns search result titles, snippets, and URLs. " <>
          "Use this to find relevant information for planning tasks.",
      parameters_schema: %{
        type: "object",
        properties: %{
          query: %{type: "string", description: "The search query"}
        },
        required: ["query"]
      },
      function: fn %{"query" => query}, _context ->
        case do_web_search(query) do
          {:ok, results} -> {:ok, results}
          {:error, reason} -> {:error, "Search failed: #{reason}"}
        end
      end
    })
  end

  defp read_webpage do
    Function.new!(%{
      name: "read_webpage",
      description:
        "Fetch and read the text content of a web page. " <>
          "Use this to get detailed information from a specific URL found via web_search. " <>
          "Content is truncated to ~8000 characters.",
      parameters_schema: %{
        type: "object",
        properties: %{
          url: %{type: "string", description: "The URL to read"}
        },
        required: ["url"]
      },
      function: fn %{"url" => url}, _context ->
        case do_read_webpage(url) do
          {:ok, content} -> {:ok, content}
          {:error, reason} -> {:error, "Failed to read page: #{reason}"}
        end
      end
    })
  end

  # --- Web search implementation (DuckDuckGo HTML) ---

  defp do_web_search(query) do
    url = "https://html.duckduckgo.com/html/"

    case Req.post(url,
           form: [q: query],
           headers: [{"user-agent", "Mozilla/5.0 (compatible; SmartTodo/1.0)"}]
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, parse_search_results(body)}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp parse_search_results(html) do
    results =
      ~r/<a rel="nofollow" class="result__a" href="([^"]+)"[^>]*>(.*?)<\/a>.*?<a class="result__snippet"[^>]*>(.*?)<\/a>/s
      |> Regex.scan(html)
      |> Enum.take(5)
      |> Enum.map(fn [_, url, title, snippet] ->
        title = strip_html(title)
        snippet = strip_html(snippet)
        url = decode_ddg_url(url)
        "**#{title}**\n#{snippet}\nURL: #{url}"
      end)
      |> Enum.join("\n\n---\n\n")

    if results == "" do
      "No results found. Try different search terms."
    else
      results
    end
  end

  defp decode_ddg_url(url) do
    case URI.parse(url) do
      %{query: query} when is_binary(query) ->
        case URI.decode_query(query) do
          %{"uddg" => real_url} -> real_url
          _ -> url
        end

      _ ->
        url
    end
  end

  # --- Webpage reading ---

  defp do_read_webpage(url) do
    case Req.get(url,
           headers: [{"user-agent", "Mozilla/5.0 (compatible; SmartTodo/1.0)"}],
           max_redirects: 5,
           receive_timeout: 15_000
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, body |> extract_text() |> String.slice(0, 8000)}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  defp extract_text(html) do
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<nav[^>]*>.*?<\/nav>/s, "")
    |> String.replace(~r/<footer[^>]*>.*?<\/footer>/s, "")
    |> strip_html()
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp strip_html(text) do
    text
    |> String.replace(~r/<br\s*\/?>/, "\n")
    |> String.replace(~r/<\/?(p|div|h[1-6]|li|tr)[^>]*>/, "\n")
    |> String.replace(~r/<[^>]+>/, " ")
    |> String.replace("&amp;", "&")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace("&nbsp;", " ")
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/ *\n */, "\n")
    |> String.trim()
  end

  # --- Response extraction ---

  defp extract_response(%Message{content: content}) when is_binary(content), do: content
  defp extract_response(%Message{content: [%{content: content} | _]}), do: content

  defp extract_response(%Message{content: content}) when is_list(content),
    do: Enum.map_join(content, "\n", & &1)

  defp extract_response(_), do: "Research complete."
end
