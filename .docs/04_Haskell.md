### April - Haskell

The Haskell implementation introduces a paradigm shift by leveraging Software Transactional Memory (STM) and a pure
functional approach to concurrency. It demonstrates how strong static typing and a rigorous memory model can virtually
eliminate entire classes of concurrency bugs, such as race conditions and deadlocks, while maintaining high performance.

### Key Technologies

- **GHC (Glasgow Haskell Compiler) 9.6+**
- **STM (Software Transactional Memory)**: A composable, lock-free approach to shared-state concurrency. It uses
  `TBQueue` (transactional bounded queue) and `TVar` (transactional variables).
- **Async Library**: Provides high-level primitives like `mapConcurrently_` for managing concurrent tasks, equivalent to
  C#'s `Task.WhenAll`.
- **Pure Functional Logic**: Separation of IO-bound orchestration from pure worker simulation logic, ensuring side
  effects are strictly controlled.
- **Strong Typing**: Extensive use of algebraic data types (ADTs) and sets to manage `Behaviour` and `ExecutionModel`.

---

### C# vs. Haskell

From a Distributed Systems perspective, comparing C# and Haskell highlights the trade-off between the flexibility of
managed imperative code and the correctness guarantees of a pure functional model.

#### 1. Composable Concurrency (STM)

- **C#**: Relies on `System.Threading.Channels` or manual locking (`lock`, `SemaphoreSlim`). While `Channels` are
  excellent for producer-consumer patterns, composing multiple atomic operations across different channels or shared
  state usually requires complex, error-prone locking logic.
- **Haskell**: STM allows for atomic blocks that are truly composable. An engineer can read from a queue and update a
  `TVar` in a single `atomically` block, guaranteeing that the entire transaction either succeeds or fails. In
  distributed systems where consistency is paramount, STM provides a "database-like" experience for in-memory state,
  significantly reducing the complexity of multi-resource synchronisation.

#### 2. Determinism and Side Effects

- **C#**: Side effects can occur anywhere. A worker processing a message might inadvertently modify global state or
  perform unlogged IO.
- **Haskell**: The `IO` monad explicitly marks functions that perform side effects. Pure functions (like the core
  simulation logic) are guaranteed to be deterministic. This makes unit testing distributed logic significantly more
  reliable, as the "business logic" of a worker is decoupled from the "plumbing" of the concurrency runtime.

#### 3. Error Handling and Totality

- **C#**: Uses exceptions for control flow and error reporting. This can lead to partial failures where a worker crashes
  but leaves shared state in an inconsistent state.
- **Haskell**: Favours explicit error types (`Either`, `Maybe`) and exhaustive pattern matching. GHC enforces that every
  branch of an `ExecutionModel` or `Behaviour` is handled at compile time. For a Distributed Systems engineer, this
  ensures that edge cases (like "unknown message types") are handled by design rather than discovered via production
  logs.

#### 4. Runtime and Latency

- **C#**: The .NET runtime is optimised for throughput. While the GC is highly advanced, it still operates on a "
  managed" basis which can introduce jitter.
- **Haskell**: GHC's lightweight thread implementation (sparks) is exceptionally efficient, often outperforming native
  threads and even some async/await implementations for high-concurrency workloads. However, Haskell's GC and lazy
  evaluation can sometimes introduce "thunks" and memory spikes if not managed carefully. In the context of a
  distributed worker, Haskell offers a unique profile: predictable state transitions through STM but requiring careful
  attention to memory profiling.
