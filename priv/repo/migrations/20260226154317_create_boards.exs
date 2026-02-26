defmodule SmartTodo.Repo.Migrations.CreateBoards do
  use Ecto.Migration

  def change do
    create table(:boards) do
      add :title, :string, null: false
      add :description, :string
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:boards, [:position])
  end
end
