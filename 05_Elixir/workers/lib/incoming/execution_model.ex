defmodule Incoming.ExecutionModel do
  @type t ::
          :one_off
          | :scheduled
          | :event_driven
          | :batch
          | :stream
          | :workflow
          | :actor

  def one_off, do: :one_off
  def scheduled, do: :scheduled
  def event_driven, do: :event_driven
  def batch, do: :batch
  def stream, do: :stream
  def workflow, do: :workflow
  def actor, do: :actor

  def all,
    do: [
      :one_off,
      :scheduled,
      :event_driven,
      :batch,
      :stream,
      :workflow,
      :actor
    ]
end
