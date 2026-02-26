defmodule SmartTodo.Todos.Board do
  use Ecto.Schema
  import Ecto.Changeset

  schema "boards" do
    field :title, :string
    field :description, :string
    field :position, :integer, default: 0

    has_many :lists, SmartTodo.Todos.List
    has_many :tasks, SmartTodo.Todos.Task

    timestamps(type: :utc_datetime)
  end

  def changeset(board, attrs) do
    board
    |> cast(attrs, [:title, :description, :position])
    |> validate_required([:title])
  end
end
