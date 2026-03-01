using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;
using Workers.Incoming;

namespace Workers;

internal readonly record struct Worker
{
    // Demo "exactly-once" ledger (process lifetime only).
    private static readonly ConcurrentDictionary<int, byte> Processed = new();

    private readonly ChannelReader<Work> _reader;

    public Worker(ChannelReader<Work> reader) => _reader = reader;

    public async Task Execute(CancellationToken cancellationToken)
    {
        while (_reader.TryRead(out var work))
        {
            Console.WriteLine(
                $"Working on item {work.Id} | Model={work.ExecutionModel:G} | Behaviour={work.Behaviour:F}");

            await SimulateAsync(work, cancellationToken);

            Console.WriteLine($"Done work {work.Id}.");
        }
    }

    private static async Task SimulateAsync(Work work, CancellationToken ct)
    {
        // Exactly-once: skip duplicates (demo-level, in-memory only).
        if (work.Behaviour.HasFlag(Behaviour.ExactlyOnce) && !Processed.TryAdd(work.Id, 0))
        {
            Console.WriteLine($"  [ExactlyOnce] Work {work.Id} already processed -> skipping.");
            return;
        }

        var attempts = work.Behaviour.HasFlag(Behaviour.Retryable) ? 3 : 1;

        for (var attempt = 1; attempt <= attempts; attempt++)
        {
            try
            {
                ct.ThrowIfCancellationRequested();

                // HighPriority: less "queueing"/overhead before work begins.
                if (work.Behaviour.HasFlag(Behaviour.HighPriority))
                {
                    Console.WriteLine("  [HighPriority] Fast-lane execution.");
                }

                // RequiresAffinity: pin to a pretend partition/worker lane.
                var lane = Math.Abs(work.Id) % 4;
                if (work.Behaviour.HasFlag(Behaviour.RequiresAffinity))
                {
                    Console.WriteLine($"  [RequiresAffinity] Routing to lane {lane}.");
                }

                await SimulateByExecutionModelAsync(work, lane, ct);

                Console.WriteLine(
                    work.Behaviour.HasFlag(Behaviour.Retryable)
                        ? $"  [Retryable] Succeeded on attempt {attempt}/{attempts}."
                        : "  Completed.");

                return;
            }
            catch (OperationCanceledException)
            {
                Console.WriteLine($"  Work cancelled");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"  Attempt {attempt}/{attempts} failed: {ex.Message}");

                if (attempt == attempts)
                {
                    Console.WriteLine("  Giving up.");
                    return;
                }

                // Tiny exponential-ish backoff for the demo.
                var backoffMs = 50 * attempt * attempt;
                await Task.Delay(backoffMs, ct);
            }
        }
    }

    private static async Task SimulateByExecutionModelAsync(Work work, int lane, CancellationToken ct)
    {
        // Base pacing. Behaviours can tweak it.
        var stepDelayMs = 80;

        if (work.Behaviour.HasFlag(Behaviour.LongRunning))
        {
            stepDelayMs += 160;
            Console.WriteLine("  [LongRunning] Slower steps.");
        }

        if (work.Behaviour.HasFlag(Behaviour.ResourceIntensive))
        {
            Console.WriteLine("  [ResourceIntensive] Adding CPU work.");
        }

        // Scheduled: pretend we had to wait until a trigger time.
        if (work.ExecutionModel == ExecutionModel.Scheduled)
        {
            Console.WriteLine("  [Scheduled] Waiting for trigger...");
            await Task.Delay(150, ct);
        }

        switch (work.ExecutionModel)
        {
            case ExecutionModel.OneOff:
                await StepAsync("OneOff: run once", stepDelayMs);
                break;

            case ExecutionModel.EventDriven:
                await StepAsync("EventDriven: handle event payload", stepDelayMs);
                break;

            case ExecutionModel.Batch:
                Console.WriteLine("  [Batch] Processing items...");
                for (var i = 1; i <= 5; i++)
                {
                    await StepAsync($"Batch item {i}/5", stepDelayMs);
                }
                break;

            case ExecutionModel.Stream:
                Console.WriteLine("  [Stream] Polling/consuming stream ticks...");
                for (var tick = 1; tick <= 4; tick++)
                {
                    await StepAsync($"Stream tick {tick}/4", stepDelayMs + 40);
                }
                break;

            case ExecutionModel.Workflow:
                Console.WriteLine("  [Workflow] Running steps (DAG-ish)...");
                await StepAsync("Step A: validate", stepDelayMs);
                await StepAsync("Step B: transform", stepDelayMs + 20);
                await StepAsync("Step C: persist", stepDelayMs + 40);
                break;

            case ExecutionModel.Actor:
                Console.WriteLine($"  [Actor] Handling partition key lane={lane} (stateful-ish).");
                await StepAsync("Actor turn: load state", stepDelayMs);
                await StepAsync("Actor turn: apply work", stepDelayMs + 20);
                await StepAsync("Actor turn: save state", stepDelayMs + 40);
                break;

            case ExecutionModel.Scheduled:
                await StepAsync("Scheduled: execute job", stepDelayMs);
                break;

            default:
                await StepAsync("Unknown model: fallback", stepDelayMs);
                break;
        }
        return;

        // Random transient failure for Retryable demos.
        void MaybeFailTransiently()
        {
            if (!work.Behaviour.HasFlag(Behaviour.Retryable))
            {
                return;
            }

            // Fail sometimes (more often when "resource intensive") so retries are visible.
            var odds = work.Behaviour.HasFlag(Behaviour.ResourceIntensive) ? 4 : 7; // 1/4 or 1/7
            if (Random.Shared.Next(odds) == 0)
            {
                throw new InvalidOperationException("Transient failure (simulated).");
            }
        }

        // ResourceIntensive: do a tiny CPU spin per step (demo only).
        static void CpuBump(int iterations)
        {
            var sw = Stopwatch.StartNew();
            var x  = 0;
            for (var i = 0; i < iterations; i++)
            {
                x = (x * 31) ^ i;
            }
            _ = x;
            sw.Stop();
        }

        Task StepAsync(string label, int delayMs)
        {
            ct.ThrowIfCancellationRequested();

            Console.WriteLine($"  -> {label}");
            if (work.Behaviour.HasFlag(Behaviour.ResourceIntensive))
            {
                CpuBump(25_000);
            }

            MaybeFailTransiently();
            return Task.Delay(delayMs, ct);
        }
    }
}