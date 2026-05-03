defmodule Program do
  alias Extras.BoundedChannel
  alias Extras.ExactlyOnceLedger
  alias Incoming.Work

  def main(args) do
    config = Configuration.new(args)

    unless Configuration.is_valid?(config) do
      IO.warn("Invalid configuration received. Shutting down...")
      System.halt(-1)
    end

    IO.puts("Valid configuration received. Starting...")

    Process.flag(:trap_exit, true)

    channel = BoundedChannel.create(config.message_count)

    Enum.each(1..config.message_count, fn i ->
      :ok = BoundedChannel.write(channel, Work.create(i))
    end)

    :ok = BoundedChannel.complete(channel)

    workers =
      Enum.map(1..config.thread_count, fn _ ->
        {:ok, pid} = Worker.start_link(channel)
        pid
      end)

    :ok = ExactlyOnceLedger.start()
    wait_for_workers(workers)

    IO.puts("Work completed. Shutting down...")
  end

  defp wait_for_workers([]), do: :ok

  defp wait_for_workers(workers) do
    receive do
      {:EXIT, pid, :normal} ->
        wait_for_workers(List.delete(workers, pid))

      {:EXIT, pid, reason} ->
        IO.puts("Worker #{inspect(pid)} crashed: #{inspect(reason)}")
        wait_for_workers(List.delete(workers, pid))
    end
  end
end
