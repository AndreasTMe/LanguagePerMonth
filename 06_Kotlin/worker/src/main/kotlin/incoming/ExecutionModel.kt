package org.andreastme.langpermonth.incoming

enum class ExecutionModel {
    OneOff,         // Single fire-and-forget unit
    Scheduled,      // Time-triggered (cron/delayed)
    EventDriven,    // Triggered by domain/infrastructure event
    Batch,          // Large dataset processing
    Stream,         // Long-lived continuous processing
    Workflow,       // DAG / multistep orchestration
    Actor;          // Key-partitioned stateful unit

    companion object {
        fun from(value: Int): ExecutionModel {
            return ExecutionModel.entries.first { it.ordinal == value }
        }
    }
}