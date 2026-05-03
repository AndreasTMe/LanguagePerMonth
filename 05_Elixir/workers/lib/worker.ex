defmodule Worker do
  alias Incoming.ExecutionModel
  alias Extras.ExactlyOnceLedger
  alias Incoming.Behaviour
  alias Extras.BoundedChannel

  def start_link(channel) do
    Task.start_link(fn -> execute(channel) end)
  end

  def execute(channel) do
    case BoundedChannel.read(channel) do
      {:ok, work} ->
        IO.puts(
          "Working on item #{work.id} | Model=#{work.execution_model} | Behaviour=#{Behaviour.to_string(work.behaviour)}"
        )

        simulate(work)

        IO.puts("Done work #{work.id}.")

        execute(channel)

      :closed ->
        :ok
    end
  end

  defp simulate(work) do
    # Exactly-once: skip duplicates (demo-level, in-memory only).
    if Behaviour.has?(work.behaviour, Behaviour.exactly_once()) and
         not ExactlyOnceLedger.try_add(work.id) do
      IO.puts("  [ExactlyOnce] Work #{work.id} already processed -> skipping.")
    else
      attempts =
        if Behaviour.has?(work.behaviour, Behaviour.retryable()) do
          3
        else
          1
        end

      for attempt <- 1..attempts do
        try do
          # HighPriority: less "queueing"/overhead before work begins.
          if Behaviour.has?(work.behaviour, Behaviour.high_priority()) do
            IO.puts("  [HighPriority] Fast-lane execution.")
          end

          # RequiresAffinity: pin to a pretend partition/worker lane.
          lane = rem(abs(work.id), 4)

          if Behaviour.has?(work.behaviour, Behaviour.requires_affinity()) do
            IO.puts("  [RequiresAffinity] Routing to lane #{lane}.")
          end

          simulate_by_execution_model(work, lane)

          if Behaviour.has?(work.behaviour, Behaviour.retryable()) do
            IO.puts("  [Retryable] Succeeded on attempt #{attempt}/#{attempts}.")
          else
            IO.puts("  Completed.")
          end

          :ok
        rescue
          e ->
            IO.puts("  Attempt #{attempt}/#{attempts} failed: #{Exception.message(e)}")

            if attempt >= attempts do
              IO.puts("  Giving up.")
              :ok
            else
              # Tiny exponential-ish backoff for the demo.
              backoff_ms = 50 * attempt * attempt
              Process.sleep(backoff_ms)
            end
        catch
          :exit, :shutdown ->
            IO.puts("  Work cancelled")

          kind, reason ->
            IO.puts("  Unexpected #{kind}: #{inspect(reason)}")
        end
      end
    end
  end

  defp simulate_by_execution_model(work, lane) do
    # Base pacing. Behaviours can tweak it.
    base_delay_ms = 80

    step_delay_ms =
      if Behaviour.has?(work.behaviour, Behaviour.long_running()) do
        IO.puts("  [LongRunning] Slower steps.")
        base_delay_ms + 160
      else
        base_delay_ms
      end

    if Behaviour.has?(work.behaviour, Behaviour.resource_intensive()) do
      IO.puts("  [ResourceIntensive] Adding CPU work.")
    end

    # Scheduled: pretend we had to wait until a trigger time.
    if work.execution_model == ExecutionModel.scheduled() do
      IO.puts("  [Scheduled] Waiting for trigger...")
      Process.sleep(150)
    end

    case work.execution_model do
      :one_off ->
        step(work, "OneOff: run once", step_delay_ms)

      :event_driven ->
        step(work, "EventDriven: handle event payload", step_delay_ms)

      :batch ->
        IO.puts("  [Batch] Processing items...")

        Enum.each(1..5, fn i ->
          step(work, "Batch item #{i}/5", step_delay_ms)
        end)

      :stream ->
        IO.puts("  [Stream] Polling/consuming stream ticks...")

        Enum.each(1..4, fn tick ->
          step(work, "Stream tick #{tick}/4", step_delay_ms + 40)
        end)

      :workflow ->
        IO.puts("  [Workflow] Running steps (DAG-ish)...")
        step(work, "Step A: validate", step_delay_ms)
        step(work, "Step B: transform", step_delay_ms + 20)
        step(work, "Step C: persist", step_delay_ms + 40)

      :actor ->
        IO.puts("  [Actor] Handling partition key lane=#{lane} (stateful-ish).")
        step(work, "Actor turn: load state", step_delay_ms)
        step(work, "Actor turn: apply work", step_delay_ms + 20)
        step(work, "Actor turn: save state", step_delay_ms + 40)

      :scheduled ->
        step(work, "Scheduled: execute job", step_delay_ms)

      _other ->
        step(work, "Unknown model: fallback", step_delay_ms)
    end
  end

  # Random transient failure for Retryable demos.
  defp maybe_fail_transiently(work) do
    if Behaviour.has?(work.behaviour, Behaviour.retryable()) do
      # Fail sometimes (more often when "resource intensive") so retries are visible.
      # 1/4 or 1/7
      odds =
        if Behaviour.has?(work.behaviour, Behaviour.resource_intensive()) do
          4
        else
          7
        end

      if Enum.random(1..odds) == 0 do
        raise "Transient failure (simulated)."
      end
    end
  end

  # ResourceIntensive: do a tiny CPU spin per step (demo only).
  defp cpu_bump(iterations) do
    {_time_us, _result} =
      :timer.tc(fn ->
        Enum.reduce(0..(iterations - 1), 0, fn i, x ->
          Bitwise.bxor(x * 31, i)
        end)
      end)
  end

  defp step(work, label, delay_ms) do
    IO.puts("  -> #{label}")

    if Behaviour.has?(work.behaviour, Behaviour.resource_intensive()) do
      cpu_bump(25000)
    end

    maybe_fail_transiently(work)
    Process.sleep(delay_ms)
  end
end
