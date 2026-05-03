defmodule Incoming.Behaviour do
  import Bitwise

  @type t :: non_neg_integer()

  @none 0
  @high_priority 1 <<< 0
  @long_running 1 <<< 1
  @resource_intensive 1 <<< 2
  @requires_affinity 1 <<< 3
  @retryable 1 <<< 4
  @exactly_once 1 <<< 5

  def none, do: @none
  def high_priority, do: @high_priority
  def long_running, do: @long_running
  def resource_intensive, do: @resource_intensive
  def requires_affinity, do: @requires_affinity
  def retryable, do: @retryable
  def exactly_once, do: @exactly_once

  @flag_names %{
    @none => :none,
    @high_priority => :high_priority,
    @long_running => :long_running,
    @resource_intensive => :resource_intensive,
    @requires_affinity => :requires_affinity,
    @retryable => :retryable,
    @exactly_once => :exactly_once
  }

  def name(flag), do: Map.fetch!(@flag_names, flag)

  def all,
    do: [
      high_priority(),
      long_running(),
      resource_intensive(),
      requires_affinity(),
      retryable(),
      exactly_once()
    ]

  def has?(flags, flag), do: (flags &&& flag) != 0

  def to_string(mask) do
    mask
    |> flags()
    |> Enum.join(", ")
  end

  defp flags(0), do: [:none]

  defp flags(mask) when is_integer(mask) and mask > 0 do
    all()
    |> Enum.flat_map(fn flag ->
      if has?(mask, flag), do: [name(flag)], else: []
    end)
  end
end
