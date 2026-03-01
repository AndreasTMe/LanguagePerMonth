#[repr(u8)]
#[derive(PartialEq, Copy, Clone, Debug)]
pub enum ExecutionModel {
    OneOff = 0,      // Single fire-and-forget unit
    Scheduled = 1,   // Time-triggered (cron/delayed)
    EventDriven = 2, // Triggered by domain/infrastructure event
    Batch = 3,       // Large dataset processing
    Stream = 4,      // Long-lived continuous processing
    Workflow = 5,    // DAG / multistep orchestration
    Actor = 6,       // Key-partitioned stateful unit
}

impl ExecutionModel {
    const EXECUTION_MODELS: [ExecutionModel; 7] = [
        ExecutionModel::OneOff,
        ExecutionModel::Scheduled,
        ExecutionModel::EventDriven,
        ExecutionModel::Batch,
        ExecutionModel::Stream,
        ExecutionModel::Workflow,
        ExecutionModel::Actor,
    ];

    pub fn get_all() -> &'static [ExecutionModel] {
        &Self::EXECUTION_MODELS
    }
}
