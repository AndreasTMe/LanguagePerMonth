### May - Elixir

The Elixir implementation demonstrates the power of the Actor model and the Erlang Virtual Machine (BEAM) for building
fault-tolerant, distributed systems. By treating every worker as an isolated process, Elixir provides a unique
perspective on concurrency that emphasises "Let it crash" resilience over defensive programming.

### Key Technologies

- **BEAM (Erlang VM)**: A runtime designed for massive concurrency, featuring lightweight processes with isolated memory
  and soft real-time guarantees.
- **Processes & Mailboxes**: Unlike OS threads or green threads, Elixir processes communicate via asynchronous message
  passing, each having its own private heap.
- **GenServer**: A behaviour for implementing client-server architectures, used here to build a custom `BoundedChannel`
  and an `ExactlyOnceLedger`.
- **Task & Link**: Used for worker orchestration and lifecycle management, allowing the main process to monitor
  and react to worker completion or failure.
- **Pattern Matching**: Extensively used for message handling and flow control, making the intent of concurrent
  interactions explicit.

---

### C# vs. Elixir

From a Distributed Systems engineering standpoint, C# and Elixir represent two fundamentally different approaches to
scaling: C# focuses on maximising throughput within a single runtime instance, while Elixir focuses on system
reliability and horizontal distribution.

#### 1. Concurrency Model: Shared Memory vs. Actors

- **C#**: Utilizes `System.Threading.Channels` and the Task Parallel Library (TPL). While these abstractions are
  highly efficient, they still operate within a shared-memory space. Ensuring thread safety requires careful
  synchronisation or the use of specific concurrent collections.
- **Elixir**: Implements the Actor model. Processes share nothing. Communication is done strictly via message
  passing. This eliminates data races by design and makes the system naturally suited for distribution across a
  cluster, as sending a message to a local process uses the same syntax as sending it to a remote node.

#### 2. Fault Tolerance: Defensive Coding vs. "Let it Crash"

- **C#**: Relies on `try/catch` blocks and supervisor patterns implemented at the application level. A single
  unhandled exception in a critical thread pool task can lead to complex state corruption or process termination.
- **Elixir**: Embraces failure. The "Let it crash" philosophy means that if a worker process fails, it is simply
  restarted (or handled) by its supervisor. The isolation ensures that a crash in one worker cannot corrupt the
  memory or state of another, providing a level of resilience that is challenging to achieve in managed runtimes like
  .NET.

#### 3. Resource Management and Scheduling

- **C#**: The .NET thread pool is highly optimised but can suffer from "noisy neighbour" effects where one long-running
  synchronous task starves others. Modern `async/await` mitigates this but requires disciplined use throughout the
  stack.
- **Elixir**: The BEAM scheduler is preemptive and uses a reduction-based approach. It ensures that no single process
  can hog the CPU, providing extremely predictable tail latencies even under a high load. This makes Elixir ideal for
  low-latency messaging and stateful orchestration.

#### 4. Introspection and Observability

- **C#**: Relies on external tools like Profilers, Debuggers, and Telemetry (OpenTelemetry) to inspect a running system.
- **Elixir**: Provides powerful built-in tools for live introspection. One can connect a remote shell to a
  production node, inspect individual process mailboxes, and even update code on the fly without restarting the
  VM. For a Distributed Systems engineer, this "live" nature is invaluable for debugging transient issues in complex,
  multi-node deployments.
