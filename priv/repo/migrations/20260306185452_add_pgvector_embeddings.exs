defmodule SmartTodo.Repo.Migrations.AddPgvectorEmbeddings do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS vector"

    alter table(:cards) do
      add :embedding, :vector, size: 768
    end

    create index("cards", ["embedding vector_cosine_ops"], using: :hnsw)
  end

  def down do
    drop index("cards", ["embedding vector_cosine_ops"])

    alter table(:cards) do
      remove :embedding
    end

    execute "DROP EXTENSION IF EXISTS vector"
  end
end
