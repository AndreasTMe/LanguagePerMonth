namespace Workers.Incoming

open System

[<Flags>]
type Behaviour =
    | None = 0uy
    | HighPriority = 1uy
    | LongRunning = 2uy
    | ResourceIntensive = 4uy
    | RequiresAffinity = 8uy
    | Retryable = 16uy
    | ExactlyOnce = 32uy
