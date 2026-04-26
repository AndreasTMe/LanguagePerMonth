### C# (Starter Project)

The C# implementation serves as the baseline for the "Language Per Month" series. It demonstrates a bounded
producer-consumer pattern using modern .NET concurrency primitives.

### Key Technologies

- **.NET 10.0**
- **System.Threading.Channels**: Used for efficient, thread-safe message passing between the producer and the workers.
- **Task Parallel Library (TPL)**: Used for managing asynchronous operations and worker tasks.
- **CancellationToken**: Ensures a clean shutdown when the process is interrupted (e.g., via Ctrl+C).

### Implementation Details

#### 1. Configuration (`Configuration.cs`)

The project uses a custom `Configuration` record to parse CLI arguments.

- `--message-count`: Number of work items to generate.
- `--thread-count`: Number of concurrent worker tasks to spawn.

#### 2. Messaging (`Work.cs`, `Behaviour.cs`, `ExecutionModel.cs`)

The core message unit is the `Work` struct, which includes:

- `Id`: A unique identifier.
- `ExecutionModel`: Randomly assigned type (e.g., `OneOff`, `Scheduled`, `Stream`).
- `Behaviour`: Flags that determine execution characteristics (e.g., `HighPriority`, `Retryable`, `ExactlyOnce`).

#### 3. Producer-Consumer Pattern (`Program.cs`)

- A **Bounded Channel** is created with a capacity equal to the message count.
- The **Producer** (main thread) populates the channel and then marks it as complete.
- **Workers** (`Worker.cs`) are spawned as independent `Task` instances. They consume items from the `ChannelReader`
  until it is exhausted.

#### 4. Worker Logic (`Worker.cs`)

Each worker:

- Reads `Work` items from the shared channel.
- Simulates execution based on the item's `Behaviour` and `ExecutionModel`.
- Handles `ExactlyOnce` logic using a `ConcurrentDictionary` to avoid duplicate processing.
- Implements `Retryable` logic with a basic exponential backoff simulation.
