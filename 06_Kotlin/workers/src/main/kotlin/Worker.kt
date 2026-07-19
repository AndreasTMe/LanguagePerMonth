package org.andreastme.langpermonth

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import org.andreastme.langpermonth.incoming.Behaviour
import org.andreastme.langpermonth.incoming.ExecutionModel
import org.andreastme.langpermonth.incoming.Work
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs
import kotlin.random.Random
import kotlin.time.Duration.Companion.milliseconds

// Demo "exactly-once" ledger (process lifetime only).
private val Processed = ConcurrentHashMap<Int, Boolean>()

class Worker(
    private val channel: Channel<Work>
) {
    suspend fun execute() {
        while (true) {
            val result = channel.tryReceive()
            if (result.isClosed) break

            val work = result.getOrNull() ?: continue
            println("Working on item ${work.id} | Model=${work.executionModel.name} | Behaviour=${work.behaviour}")

            simulate(work)

            println("Done work ${work.id}.")
        }
    }

    private suspend fun simulate(work: Work) {
        // Exactly-once: skip duplicates (demo-level, in-memory only).
        if (work.behaviour.hasFlag(Behaviour.ExactlyOnce) && Processed.containsKey(work.id)) {
            println("  [ExactlyOnce] Work ${work.id} already processed -> skipping.")
            return
        }

        Processed[work.id] = true

        val attempts = if (work.behaviour.hasFlag(Behaviour.Retryable)) 3 else 1

        for (attempt in 1..attempts) {
            try {
                // HighPriority: less "queueing"/overhead before work begins.
                if (work.behaviour.hasFlag(Behaviour.HighPriority)) {
                    println("  [HighPriority] Fast-lane execution.")
                }

                // RequiresAffinity: pin to a pretend partition/worker lane.
                val lane = abs(work.id) % 4
                if (work.behaviour.hasFlag(Behaviour.RequiresAffinity)) {
                    println("  [RequiresAffinity] Routing to lane $lane.")
                }

                simulateByExecutionModel(work, lane)

                println(
                    if (work.behaviour.hasFlag(Behaviour.Retryable)) {
                        "  [Retryable] Succeeded on attempt $attempt/$attempts."
                    } else {
                        "  Completed."
                    }
                )

                return
            } catch (e: Throwable) {
                if (e is CancellationException) {
                    println("  Work cancelled")
                    throw e
                }

                println("  Attempt $attempt/$attempts failed: ${e.message}")

                if (attempt == attempts) {
                    println("  Giving up.")
                    return
                }

                // Tiny exponential-ish backoff for the demo.
                val backoffMs = 50 * attempt * attempt
                delay(backoffMs.milliseconds)
            }
        }
    }

    private suspend fun simulateByExecutionModel(work: Work, lane: Int) {
        // Base pacing. Behaviours can tweak it.
        var stepDelayMs = 80

        if (work.behaviour.hasFlag(Behaviour.LongRunning)) {
            stepDelayMs += 160
            println("  [LongRunning] Slower steps.")
        }

        if (work.behaviour.hasFlag(Behaviour.ResourceIntensive)) {
            println("  [ResourceIntensive] Adding CPU work.")
        }

        // Scheduled: pretend we had to wait until a trigger time.
        if (work.executionModel == ExecutionModel.Scheduled) {
            println("  [Scheduled] Waiting for trigger...")
            delay(150.milliseconds)
        }

        when (work.executionModel) {
            ExecutionModel.OneOff -> {
                step(work, "OneOff: run once", stepDelayMs)
            }

            ExecutionModel.EventDriven -> {
                step(work, "EventDriven: handle event payload", stepDelayMs)
            }

            ExecutionModel.Batch -> {
                println("  [Batch] Processing items...")
                for (i in 1..5) {
                    step(work, "Batch item $i/5", stepDelayMs)
                }
            }

            ExecutionModel.Stream -> {
                println("  [Stream] Polling/consuming stream ticks...")
                for (tick in 1..4) {
                    step(work, $"Stream tick $tick/4", stepDelayMs + 40)
                }
            }

            ExecutionModel.Workflow -> {
                println("  [Workflow] Running steps (DAG-ish)...")
                step(work, "Step A: validate", stepDelayMs)
                step(work, "Step B: transform", stepDelayMs + 20)
                step(work, "Step C: persist", stepDelayMs + 40)
            }

            ExecutionModel.Actor -> {
                println("  [Actor] Handling partition key lane=$lane (stateful-ish).")
                step(work, "Actor turn: load state", stepDelayMs)
                step(work, "Actor turn: apply work", stepDelayMs + 20)
                step(work, "Actor turn: save state", stepDelayMs + 40)
            }

            ExecutionModel.Scheduled -> {
                step(work, "Scheduled: execute job", stepDelayMs)
            }
        }
    }

    // Random transient failure for Retryable demos.
    private fun maybeFailTransiently(work: Work) {
        if (!work.behaviour.hasFlag(Behaviour.Retryable)) {
            return
        }

        // Fail sometimes (more often when "resource intensive") so retries are visible.
        val odds = if (work.behaviour.hasFlag(Behaviour.ResourceIntensive)) 4 else 7 // 1/4 or 1/7
        if (Random.nextInt(odds) == 0) {
            throw IllegalStateException("Transient failure (simulated).")
        }
    }

    // ResourceIntensive: do a tiny CPU spin per step (demo only).
    @Suppress("SameParameterValue")
    private fun cpuBump(iterations: Int) {
        var x = 0

        for (i in 0 until iterations) {
            x = (x * 31) xor i
        }

        x.hashCode()
    }

    private suspend fun step(work: Work, label: String, delayMs: Int) {
        println("  -> $label")
        if (work.behaviour.hasFlag(Behaviour.ResourceIntensive)) {
            cpuBump(25_000)
        }

        maybeFailTransiently(work)
        delay(delayMs.milliseconds)
    }
}
