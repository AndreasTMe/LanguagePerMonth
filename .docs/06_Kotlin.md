### June - Kotlin

The Kotlin implementation targets the JVM through structured concurrency, using coroutines instead of raw threads to
model the same producer/worker challenge. It shows how a language built as a pragmatic evolution of Java can bring
lightweight, suspendable concurrency to a runtime traditionally associated with heavyweight OS threads.

### Key Technologies

- **Kotlin/JVM 2.3+ (JVM toolchain 25)**: Runs on the same JVM as C#'s CLR-equivalent peers, but compiles coroutines
  down to suspend functions rather than relying on the platform's native threading model.
- **kotlinx.coroutines**: Provides `Channel<T>` for producer/consumer hand-off, `launch` for structured concurrency,
  and `runBlocking` to bridge the coroutine world with the blocking `main` entry point.
- **`SupervisorJob`**: Roots the coroutine hierarchy so that a failure in one worker coroutine does not automatically
  cancel its siblings, and gives the JVM shutdown hook a single handle to cancel all in-flight work.
- **Value Classes (`@JvmInline value class`)**: Used for `Behaviour`, wrapping a `Byte` bitmask with zero runtime
  allocation overhead - a compile-time-only abstraction over a primitive.
- **Sealed Interfaces & Data Objects**: `Configuration` models "valid" vs. "invalid" CLI input as a closed type
  hierarchy, letting `when` expressions be checked exhaustively by the compiler.

---

### C# vs. Kotlin

Both C# and Kotlin target managed runtimes (CLR and JVM respectively) and both lean on async/coroutine-based
concurrency rather than manual thread management, making this comparison less about "different worlds" and more
about how two languages converge on similar ideas from different starting points.

#### 1. Concurrency Model: Tasks vs. Structured Coroutines

- **C#**: `Task`-based `async/await` schedules work onto the thread pool. Cancellation is cooperative but external
  to the type system - a `CancellationToken` must be threaded manually through every call that should observe it.
- **Kotlin**: Coroutines are structured by construction. Launching a coroutine inside a `CoroutineScope` (here, the
  `runBlocking` scope rooted at a `SupervisorJob`) ties its lifetime to that scope, so cancelling the parent job -
  as the shutdown hook does - propagates to every worker without threading a token through each function signature.

#### 2. Channels: Familiar Shape, Different Guarantees

- **C#**: `System.Threading.Channels` gives a `Channel<T>` with configurable bounded/unbounded capacity and
  `Reader`/`Writer` halves, consumed via `await foreach` or `TryRead`.
- **Kotlin**: `kotlinx.coroutines.channels.Channel<T>` is conceptually the same producer/consumer primitive, but
  since it is itself a suspend-based abstraction, both sending and receiving suspend the calling coroutine instead
  of blocking a thread - so a bounded channel with many producers costs coroutines, not OS threads, while backed up.

#### 3. Sum Types and Exhaustiveness

- **C#**: Prior to modern pattern-matching improvements, modelling a closed set of variants (like a valid/invalid
  configuration) leaned on inheritance or enums with an implicit "default" case that the compiler cannot fully
  verify.
- **Kotlin**: `sealed interface Configuration` with a `data class Valid` and `data object Invalid` gives the
  compiler a closed hierarchy. The `when (configuration)` in `Main.kt` is exhaustive without an `else` branch -
  adding a third variant later would fail to compile until every `when` handling it is updated, which is valuable
  for a Distributed Systems engineer extending message-handling logic without silently missing a case.

#### 4. Runtime Footprint and Interop

- **C#**: The CLR's `Task` type and thread-pool infrastructure are deeply integrated into the .NET ecosystem.
  The BCL and most modern .NET libraries expose asynchronous APIs using `Task`/`ValueTask`, allowing async composition
  through language features (`async`/`await`) and runtime support.
- **Kotlin**: Coroutines are primarily a library-level abstraction (`kotlinx.coroutines`) built on top of JVM threads,
  rather than a runtime primitive equivalent to CLR `Task`. The Kotlin compiler transforms `suspend` functions into
  continuation-based state machines. A suspended coroutine does not occupy a thread while waiting, making it significantly
  cheaper than a blocked thread.