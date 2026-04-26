module ExecutionModel
  ( ExecutionModel (..),
  )
where

data ExecutionModel
  = OneOff -- Single fire-and-forget unit
  | Scheduled -- Time-triggered (cron/delayed)
  | EventDriven -- Triggered by domain/infrastructure event
  | Batch -- Large dataset processing
  | Stream -- Long-lived continuous processing
  | Workflow -- DAG / multistep orchestration
  | Actor -- Key-partitioned stateful unit
  deriving (Show, Eq, Ord, Enum, Bounded)