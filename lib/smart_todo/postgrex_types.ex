Postgrex.Types.define(
  SmartTodo.PostgrexTypes,
  Pgvector.extensions() ++ Ecto.Adapters.Postgres.extensions(),
  []
)
