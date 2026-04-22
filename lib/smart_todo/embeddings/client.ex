defmodule SmartTodo.Embeddings.Client do
  @moduledoc """
  Client for generating embeddings via the Google Generative AI API.
  Converts a list of strings into embedding vectors.
  """

  @base_url "https://generativelanguage.googleapis.com/v1beta/models"
  @dimensions 768

  @doc """
  Generates embeddings for a list of texts.

  Returns `{:ok, [embedding]}` where each embedding is a list of floats,
  or `{:error, reason}`.
  """
  def embed(texts) when is_list(texts) do
    model = Application.get_env(:smart_todo, :embeddings_model, "gemini-embedding-001")
    api_key = Application.get_env(:langchain, :google_ai_key)

    requests =
      Enum.map(texts, fn text ->
        %{
          "model" => "models/#{model}",
          "content" => %{"parts" => [%{"text" => text}]},
          "outputDimensionality" => @dimensions
        }
      end)

    url = "#{@base_url}/#{model}:batchEmbedContents"

    case Req.post(url,
           json: %{"requests" => requests},
           params: [key: api_key]
         ) do
      {:ok, %{status: 200, body: %{"embeddings" => embeddings}}} ->
        vectors = Enum.map(embeddings, & &1["values"])
        {:ok, vectors}

      {:ok, %{status: status, body: body}} ->
        {:error, "Google API error #{status}: #{inspect(body)}"}

      {:error, exception} ->
        {:error, "HTTP error: #{Exception.message(exception)}"}
    end
  end

  @doc """
  Generates an embedding for a single text string.

  Returns `{:ok, embedding}` or `{:error, reason}`.
  """
  def embed_one(text) when is_binary(text) do
    case embed([text]) do
      {:ok, [embedding]} -> {:ok, embedding}
      {:error, reason} -> {:error, reason}
    end
  end
end
