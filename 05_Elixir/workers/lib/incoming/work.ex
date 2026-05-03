defmodule Incoming.Work do
  import Bitwise

  alias Incoming.Behaviour
  alias Incoming.ExecutionModel

  defstruct id: 0,
            execution_model: :one_off,
            behaviour: :none

  @type t :: %__MODULE__{
          id: integer(),
          execution_model: ExecutionModel.t(),
          behaviour: Behaviour.t()
        }

  def create(id)
      when is_integer(id) do
    struct(%__MODULE__{
      id: id,
      execution_model: pick_random_execution_model(),
      behaviour: pick_random_behaviour()
    })
  end

  defp pick_random_execution_model do
    ExecutionModel.all()
    |> Enum.random()
  end

  defp pick_random_behaviour do
    values = Behaviour.all()

    {mask, singles} =
      Enum.reduce(values, {0, []}, fn value, {mask, singles} ->
        cond do
          value == 0 ->
            {mask, singles}

          not atomic_flag?(value) ->
            {mask, singles}

          true ->
            mask =
              if :rand.uniform(2) == 1 do
                mask ||| value
              else
                mask
              end

            {mask, [value | singles]}
        end
      end)

    final_mask =
      if mask == 0 and singles != [] do
        Enum.random(singles)
      else
        mask
      end

    final_mask
  end

  defp atomic_flag?(0), do: false
  defp atomic_flag?(n), do: (n &&& n - 1) == 0
end
