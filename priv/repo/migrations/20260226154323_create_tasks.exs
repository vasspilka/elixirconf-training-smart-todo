defmodule SmartTodo.Repo.Migrations.CreateCards do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :title, :string, null: false
      add :description, :string
      add :position, :integer, null: false, default: 0
      add :priority, :string, null: false, default: "medium"
      add :due_date, :date
      add :labels, {:array, :string}, null: false, default: []
      add :archived_at, :utc_datetime
      add :list_id, references(:lists, on_delete: :delete_all), null: false
      add :board_id, references(:boards, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cards, [:list_id])
    create index(:cards, [:board_id])
    create index(:cards, [:archived_at])
  end
end
