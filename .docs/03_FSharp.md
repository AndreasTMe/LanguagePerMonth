### March - F#

The F# implementation offers a functional-first perspective on the .NET ecosystem. While it shares the same
high-performance runtime as C#, it uses F#'s unique syntax and paradigms to express concurrency and data flow,
emphasising immutability and declarative logic in distributed workloads.

### Key Technologies

- **.NET 10.0+**
- **System.Threading.Channels**: Reused from the .NET library, demonstrating F#'s seamless interoperability with C#
  infrastructure.
- **Task Expressions (`task {}`)**: Native support for asynchronous programming, providing a more concise and often
  safer way to handle `Task`-based concurrency compared to C#'s `async/await`.
- **Discriminated Unions and Pattern Matching**: Used to define and handle execution models and behaviours, leading to
  more exhaustive and readable orchestration logic.

---

### C# vs. F#

In the context of Distributed Systems, the comparison between C# and F# is less about the underlying runtime (which is
identical) and more about how the language prevents common architectural pitfalls and manages complexity.

#### 1. Immutability and State Management

- **C#**: While modern C# supports `record` types and `readonly` fields, it remains imperative at its core. In highly
  concurrent systems, accidental state mutation is a common source of race conditions.
- **F#**: Defaults to immutability. By encouraging pure functions and immutable data structures, F# reduces the
  cognitive load when reasoning about state transitions across multiple threads. In a distributed worker, this "safety
  by default" approach minimises side effects and makes unit testing complex logic significantly easier.

#### 2. Pattern Matching and Domain Modelling

- **C#**: Uses `switch` statements or expressions, which have improved but can still feel bolted-on when dealing with
  complex object hierarchies.
- **F#**: Pattern matching is a first-class citizen. When handling different `ExecutionModel` types (Batch, Stream,
  Actor), the F# compiler can enforce exhaustiveness checks. For a Distributed Systems engineer, this ensures that every
  message type or error condition is explicitly accounted for, preventing "unhandled case" bugs in production.

#### 3. Concurrency Ergonomics

- **C#**: The TPL and `async/await` are robust but can lead to verbose boilerplate, especially when passing
  `CancellationToken` through every layer or handling complex task compositions.
- **F#**: `task {}` expressions and the pipe operator (`|>`) allow for a more fluent and composable way to describe
  asynchronous workflows. F# also has `Async` workflows (the older model), but its modern `task` support provides
  zero-overhead interoperability with C# libraries like `Channels` while maintaining a functional aesthetic.

#### 4. Error Handling and Correctness

- **C#**: Heavily reliant on exceptions for both expected and unexpected failures.
- **F#**: While it supports exceptions, the F# community prefers the `Result` type for expected failures. This forces
  the engineer to handle error paths as part of the domain logic. In this challenge, the F# version's use of pattern
  matching over behaviours like `Retryable` or `ExactlyOnce` leads to code that is often more self-documenting and less
  prone to "silent" failures common in complex imperative loops.
