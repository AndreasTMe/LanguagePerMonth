# Language Per Month Project

A small “same-problem, different-language” series: each month adds a new implementation of the exact same concurrency
exercise.

## The Challenge (shared across all months)

Each implementation must:

1. Receive a **message count** and a **thread/worker count** from the CLI
2. Create `{messageCount}` work items and push them into a single shared queue/channel (or the closest equivalent in
   that language)
3. Start `{threadCount}` workers
4. Consume work items from that single queue/channel until exhausted
5. Shut down cleanly (no hanging workers, no leaked tasks)

## Project Structure

**Starter:** `Month00_CSharp/` - C#

| **Month** | **Directory**   | **Language** |
|-----------|-----------------|--------------|
| January   | `Month01_Rust/` | Rust         |
| February  | `Month02_Go/`   | Go           |

Each month folder is intended to be self-contained and runnable from its own directory.

## Starting project in C#

```bash
cd Month00_CSharp && dotnet run --project Workers/Workers.csproj  --message-count 20 --thread-count 4 && cd ..
```

## January - Rust

```bash
cd Month01_Rust && cargo run . --message-count 20 --thread-count 4 && cd ..
```

## February - Go

```bash
cd Month02_Go && go run . --message-count 20 --thread-count 4 && cd ..
```

## Notes / Conventions

- **CLI flags:** All projects aim to accept the same flags:
    - `--message-count <int>`
    - `--thread-count <int>`
- **Output:** Keep output simple and comparable between languages (e.g. worker id and processed item id), but don't
  worry about exact matching logs.
- **Correctness over cleverness:** The goal is to learn the language/runtime primitives (channels, thread pools, async
  runtimes, etc.) while keeping the problem identical.