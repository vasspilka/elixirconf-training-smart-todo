defmodule SmartTodo.Todos.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :position, :integer, default: 0
    field :priority, Ecto.Enum, values: [:low, :medium, :high, :urgent], default: :medium
    field :due_date, :date
    field :labels, {:array, :string}, default: []
    field :archived_at, :utc_datetime

    belongs_to :list, SmartTodo.Todos.List
    belongs_to :board, SmartTodo.Todos.Board

    timestamps(type: :utc_datetime)
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [
      :title,
      :description,
      :position,
      :priority,
      :due_date,
      :labels,
      :archived_at,
      :list_id,
      :board_id
    ])
    |> validate_required([:title, :list_id, :board_id])
    |> foreign_key_constraint(:list_id)
    |> foreign_key_constraint(:board_id)
  end
end
