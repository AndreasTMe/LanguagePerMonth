defmodule Configuration do
  defstruct message_count: 0, thread_count: 0

  @type t :: %__MODULE__{
          message_count: non_neg_integer(),
          thread_count: non_neg_integer()
        }

  def is_valid?(%__MODULE__{message_count: mc, thread_count: tc})
      when is_integer(mc) and is_integer(tc) do
    mc > 0 and tc > 0
  end

  def is_valid?(_), do: false

  def new(args) do
    args
    |> Enum.chunk_every(2)
    |> Enum.reduce(%{}, fn
      ["--message-count", value], acc ->
        Map.put(acc, :message_count, parse_pos_int(value))

      ["--thread-count", value], acc ->
        Map.put(acc, :thread_count, parse_pos_int(value))

      [flag, _value], _acc ->
        IO.warn("Unknown argument: #{flag}")

      invalid, _acc ->
        IO.warn("Invalid argument pair: #{inspect(invalid)}")
    end)
    |> then(fn opts ->
      struct(__MODULE__, opts)
    end)
  end

  defp parse_pos_int(value) do
    case Integer.parse(value) do
      {int, ""} when int >= 0 ->
        int

      _ ->
        IO.warn("Invalid integer: #{value}")
        0
    end
  end
end
