defmodule SmartTodo.Todos.List do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lists" do
    field :title, :string
    field :position, :integer, default: 0

    belongs_to :board, SmartTodo.Todos.Board
    has_many :cards, SmartTodo.Todos.Card

    timestamps(type: :utc_datetime)
  end

  def changeset(list, attrs) do
    list
    |> cast(attrs, [:title, :position, :board_id])
    |> validate_required([:title, :board_id])
    |> foreign_key_constraint(:board_id)
  end
end
