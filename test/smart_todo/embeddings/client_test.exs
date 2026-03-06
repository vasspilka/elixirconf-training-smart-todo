defmodule SmartTodo.Embeddings.ClientTest do
  use ExUnit.Case, async: true

  alias SmartTodo.Embeddings.Client

  @moduletag :live

  describe "embed/1" do
    test "returns embeddings for a list of texts" do
      {:ok, embeddings} = Client.embed(["Hello world", "Elixir programming"])

      assert length(embeddings) == 2
      assert Enum.all?(embeddings, &is_list/1)
      assert Enum.all?(embeddings, fn e -> length(e) == 768 end)
    end

    test "returns embeddings with correct dimensionality" do
      {:ok, [embedding]} = Client.embed(["Test text"])

      assert length(embedding) == 768
      assert Enum.all?(embedding, &is_float/1)
    end
  end

  describe "embed_one/1" do
    test "returns a single embedding vector" do
      {:ok, embedding} = Client.embed_one("Hello world")

      assert is_list(embedding)
      assert length(embedding) == 768
    end
  end
end
