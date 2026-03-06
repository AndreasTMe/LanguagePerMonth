namespace Workers.Incoming

type ExecutionModel =
    | OneOff = 0uy // Single fire-and-forget unit
    | Scheduled = 1uy // Time-triggered (cron/delayed)
    | EventDriven = 2uy // Triggered by domain/infrastructure event
    | Batch = 3uy // Large dataset processing
    | Stream = 4uy // Long-lived continuous processing
    | Workflow = 5uy // DAG / multistep orchestration
    | Actor = 6uy // Key-partitioned stateful unit
