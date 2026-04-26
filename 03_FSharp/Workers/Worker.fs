namespace Workers

open System
open System.Collections.Concurrent
open System.Diagnostics
open System.Threading
open System.Threading.Channels
open System.Threading.Tasks
open Workers.Incoming

type Worker(reader: ChannelReader<Work>) =

    // Demo "exactly-once" ledger (process lifetime only).
    static let processed = ConcurrentDictionary<int, byte>()

    member public this.Execute(cancellationToken: CancellationToken) : Task =
        task {
            let mutable work = Unchecked.defaultof<Work>

            while reader.TryRead(&work) do
                Console.WriteLine(
                    $"Working on item {work.Id} | Model={work.ExecutionModel:G} | Behaviour={work.Behaviour:F}"
                )

                do! Worker.Simulate(work, cancellationToken)

                Console.WriteLine($"Done work {work.Id}.")
        }

    static member private Simulate(work: Work, cancellationToken: CancellationToken) : Task =
        task {
            // Exactly-once: skip duplicates (demo-level, in-memory only).
            if
                work.Behaviour.HasFlag(Behaviour.ExactlyOnce)
                && not (processed.TryAdd(work.Id, 0uy))
            then
                Console.WriteLine($"  [ExactlyOnce] Work {work.Id} already processed -> skipping.")
            else
                let attempts = if work.Behaviour.HasFlag(Behaviour.Retryable) then 3 else 1

                for attempt in 1..attempts do
                    try
                        cancellationToken.ThrowIfCancellationRequested()

                        // HighPriority: less "queueing"/overhead before work begins.
                        if work.Behaviour.HasFlag(Behaviour.HighPriority) then
                            Console.WriteLine("  [HighPriority] Fast-lane execution.")

                        // RequiresAffinity: pin to a pretend partition/worker lane.
                        let lane = Math.Abs(work.Id) % 4

                        if work.Behaviour.HasFlag(Behaviour.RequiresAffinity) then
                            Console.WriteLine($"  [RequiresAffinity] Routing to lane {lane}.")

                        do! Worker.SimulateByExecutionModel(work, lane, cancellationToken)

                        Console.WriteLine(
                            if work.Behaviour.HasFlag(Behaviour.Retryable) then
                                $"  [Retryable] Succeeded on attempt {attempt}/{attempts}."
                            else
                                "  Completed."
                        )

                    with
                    | :? OperationCanceledException -> Console.WriteLine("  Work cancelled")
                    | ex ->
                        Console.WriteLine($"  Attempt {attempt}/{attempts} failed: {ex.Message}")

                        if attempt = attempts then
                            Console.WriteLine("  Giving up.")
                        else
                            // Tiny exponential-ish backoff for the demo.
                            let backoffMs = 50 * attempt * attempt

                            do! Task.Delay(backoffMs, cancellationToken)

                            Console.WriteLine($"  Work cancelled{ex.Message}")
        }

    static member private SimulateByExecutionModel(work: Work, lane: int, cancellationToken: CancellationToken) : Task =
        task {
            // Base pacing. Behaviours can tweak it.
            let stepDelayMs =
                match work.Behaviour with
                | Behaviour.LongRunning ->
                    Console.WriteLine("  [LongRunning] Slower steps.")
                    240
                | _ -> 80

            if work.Behaviour.HasFlag(Behaviour.ResourceIntensive) then
                Console.WriteLine("  [ResourceIntensive] Adding CPU work.")

            // Scheduled: pretend we had to wait until a trigger time.
            if work.ExecutionModel = ExecutionModel.Scheduled then
                Console.WriteLine("  [Scheduled] Waiting for trigger...")
                do! Task.Delay(150, cancellationToken)

            match work.ExecutionModel with
            | ExecutionModel.OneOff ->
                do! Worker.Step("OneOff: run once", work.Behaviour, stepDelayMs, cancellationToken)
            | ExecutionModel.EventDriven ->
                do! Worker.Step("EventDriven: handle event payload", work.Behaviour, stepDelayMs, cancellationToken)
            | ExecutionModel.Batch ->
                Console.WriteLine("  [Batch] Processing items...")

                for i in 1..5 do
                    do! Worker.Step($"Batch item {i}/5", work.Behaviour, stepDelayMs, cancellationToken)
            | ExecutionModel.Stream ->
                Console.WriteLine("  [Stream] Polling/consuming stream ticks...")

                for i in 1..4 do
                    do! Worker.Step($"Stream tick {i}/5", work.Behaviour, stepDelayMs + 40, cancellationToken)
            | ExecutionModel.Workflow ->
                Console.WriteLine("  [Workflow] Running steps (DAG-ish)...")

                do! Worker.Step("Step A: validate", work.Behaviour, stepDelayMs, cancellationToken)
                do! Worker.Step("Step B: transform", work.Behaviour, stepDelayMs + 20, cancellationToken)
                do! Worker.Step("Step C: persist", work.Behaviour, stepDelayMs + 40, cancellationToken)
            | ExecutionModel.Actor ->
                Console.WriteLine($"  [Actor] Handling partition key lane={lane} (stateful-ish).")

                do! Worker.Step("Actor turn: load state", work.Behaviour, stepDelayMs, cancellationToken)
                do! Worker.Step("Actor turn: apply work", work.Behaviour, stepDelayMs + 20, cancellationToken)
                do! Worker.Step("Actor turn: save state", work.Behaviour, stepDelayMs + 40, cancellationToken)
            | ExecutionModel.Scheduled ->
                do! Worker.Step("Scheduled: execute job", work.Behaviour, stepDelayMs, cancellationToken)
            | _ -> do! Worker.Step("Unknown model: fallback", work.Behaviour, stepDelayMs, cancellationToken)
        }

    static member private Step
        (label: string, behaviour: Behaviour, delayMs: int, cancellationToken: CancellationToken)
        : Task =
        cancellationToken.ThrowIfCancellationRequested()

        Console.WriteLine($"  -> {label}")

        if behaviour.HasFlag(Behaviour.ResourceIntensive) then
            Worker.CpuBump(25_000)

        Worker.MaybeFailTransiently(behaviour)
        Task.Delay(delayMs, cancellationToken)

    // Random transient failure for Retryable demos.
    static member private MaybeFailTransiently(behaviour: Behaviour) : unit =
        if behaviour.HasFlag(Behaviour.Retryable) then
            ()
        else
            // Fail sometimes (more often when "resource intensive") so retries are visible.
            let odds =
                if behaviour.HasFlag(Behaviour.ResourceIntensive) then
                    4
                else
                    7 // 1/4 or 1/7

            if Random.Shared.Next(odds) = 0 then
                raise (InvalidOperationException("Transient failure (simulated)."))

    // ResourceIntensive: do a tiny CPU spin per step (demo only).
    static member private CpuBump(iterations: int) : unit =
        let sw = Stopwatch.StartNew()

        let x = seq { 0..iterations } |> Seq.fold (fun acc i -> (acc * 31) ^^^ i) 0
        ignore x

        sw.Stop()
