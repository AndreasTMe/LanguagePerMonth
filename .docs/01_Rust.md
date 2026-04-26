### January - Rust

The Rust implementation leverages the `tokio` async runtime to manage high-concurrency workloads with minimal resource
overhead. It provides a look into how systems-level control over memory and task scheduling can be used to build highly
resilient and performant distributed components.

### Key Technologies

- **Tokio**: An asynchronous runtime providing multi-threaded scheduling, task management, and synchronisation
  primitives.
- **MPSC Channels**: Multi-producer, single-consumer channels for message passing. To facilitate multi-worker
  consumption, the receiver is shared via an `Arc<Mutex<...>>` wrapper.
- **JoinSet**: A specialised task group for managing dynamic sets of concurrent operations, ensuring clean task
  lifecycle management.
- **CancellationToken**: Used for orchestrating graceful shutdowns across distributed worker nodes.

---

### C# vs. Rust

When architecting distributed systems, the choice between C# and Rust often hinges on the trade-offs between managed
abstraction and explicit resource control.

#### 1. Concurrency and Memory Safety

- **C#**: Utilizes `System.Threading.Channels`, which are optimised for multi-reader/multi-writer scenarios. The
  abstraction is high-level and thread-safe by design, hiding the complexity of lock-free data structures.
- **Rust**: Through `tokio`, Rust forces explicit synchronisation. The `Arc<Mutex<Receiver<T>>>` pattern makes the cost
  of sharing a single-consumer channel visible. This explicitness, combined with the borrow checker, guarantees the
  absence of data races at compile time, a critical property when building concurrent systems where state corruption is
  challenging to debug.

#### 2. Resource Utilisation and Latency

- **C#**: The .NET Managed Thread Pool and Garbage Collector (GC) introduce non-deterministic pauses. While modern .NET
  is highly performant, GC "Stop the World" events can impact tail latency (P99) in high-throughput streaming
  applications.
- **Rust**: Offers zero-cost abstractions and deterministic memory management (no GC). By eliminating runtime overhead
  for memory tracking, Rust provides predictable latency profiles and significantly lower memory footprints. This makes
  it ideal for building infrastructure components like sidecars, API gateways, or edge compute nodes where resource
  density and latency consistency are paramount.

#### 3. Error Handling and System Resilience

- **C#**: Relies on exception-based error handling. In distributed contexts, unhandled exceptions can lead to "poison
  pill" scenarios or unexpected worker crashes if not meticulously caught.
- **Rust**: Uses `Result<T, E>`, forcing engineers to handle potential failures explicitly at every step. The use of the
  `?` operator allows for concise yet safe error propagation. This "fail-fast" philosophy ensures that error states are
  considered as part of the primary control flow, leading to more robust systems in the face of transient failures or
  malformed inputs.

#### 4. Task Orchestration and Cancellation

Both implementations use a cancellation token pattern, but the ergonomics differ. C# requires passing a
`CancellationToken` through the entire call stack. Rust's `tokio::select!` macro allows for a more declarative approach
to cancellation, enabling a task to respond to shutdown signals or timeouts without polluting every internal function
signature. This leads to cleaner, more maintainable orchestration logic in complex service architectures.