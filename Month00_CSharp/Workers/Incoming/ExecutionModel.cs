namespace Workers.Incoming;

internal enum ExecutionModel : byte
{
    OneOff      = 0, // Single fire-and-forget unit
    Scheduled   = 1, // Time-triggered (cron/delayed)
    EventDriven = 2, // Triggered by domain/infrastructure event
    Batch       = 3, // Large dataset processing
    Stream      = 4, // Long-lived continuous processing
    Workflow    = 5, // DAG / multistep orchestration
    Actor       = 6  // Key-partitioned stateful unit
}