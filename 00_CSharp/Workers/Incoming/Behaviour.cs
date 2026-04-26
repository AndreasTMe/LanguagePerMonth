using System;

namespace Workers.Incoming;

[Flags]
internal enum Behaviour : byte
{
    None = 0,

    HighPriority      = 1 << 0,
    LongRunning       = 1 << 1,
    ResourceIntensive = 1 << 2,
    RequiresAffinity  = 1 << 3,
    Retryable         = 1 << 4,
    ExactlyOnce       = 1 << 5
}