use crate::incoming::behaviour::Behaviour;
use crate::incoming::work::Work;
use rand::rngs::StdRng;
use rand::{RngExt, SeedableRng};
use std::collections::HashSet;
use std::io;
use std::io::{Error, ErrorKind};
use std::sync::{Arc, Mutex as StdMutex, OnceLock};
use std::time::{Duration, Instant};
use tokio::sync::Mutex as TokioMutex;
use tokio_util::sync::CancellationToken;

use crate::incoming::execution_model::ExecutionModel;
use tokio::sync::mpsc::Receiver;
use tokio::time::sleep;

// Demo "exactly-once" ledger (process lifetime only).
static PROCESSED: OnceLock<StdMutex<HashSet<usize>>> = OnceLock::new();

fn create_ledger() -> &'static StdMutex<HashSet<usize>> {
    PROCESSED.get_or_init(|| StdMutex::new(HashSet::new()))
}

fn try_mark_processed(id: usize) -> bool {
    let mut map = create_ledger()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    map.insert(id)
}

pub struct Worker {
    receiver: Arc<TokioMutex<Receiver<Work>>>,
}

impl Worker {
    pub fn create(receiver: Arc<TokioMutex<Receiver<Work>>>) -> Worker {
        let _ = create_ledger();
        Worker { receiver }
    }

    pub async fn execute(&mut self, cancellation_token: CancellationToken) {
        loop {
            let maybe_work: Option<Work> = tokio::select! {
                _ = cancellation_token.cancelled() => {
                    println!("Worker cancelled");
                    return;
                }
                work = async {
                    let mut rx = self.receiver.lock().await;
                    rx.recv().await
                } => work,
            };

            let Some(work) = maybe_work else {
                // Channel closed and drained.
                return;
            };

            println!(
                "Working on message {} | Model={:?} | Behaviour={:?}",
                work.get_id(),
                work.get_execution_model(),
                work.get_behaviour(),
            );

            Self::simulate(&work, cancellation_token.clone()).await;

            println!("Done message {}", work.get_id());
        }
    }

    async fn simulate(work: &Work, cancellation_token: CancellationToken) {
        let behaviour = work.get_behaviour();

        // Exactly-once: skip duplicates (demo-level, in-   memory only).
        if behaviour.contains(Behaviour::EXACTLY_ONCE) && !try_mark_processed(work.get_id()) {
            println!(
                "  [ExactlyOnce] Work {} already processed -> skipping.",
                work.get_id()
            );
            return;
        }

        let attempts = if behaviour.contains(Behaviour::RETRYABLE) {
            3
        } else {
            1
        };

        for attempt in 1..=attempts {
            tokio::select! {
                _ = cancellation_token.cancelled() => {
                    println!("  Work cancelled");
                    return;
                }
                _ = async {
                    // HighPriority: less "queueing"/overhead before work begins.
                    if behaviour.contains(Behaviour::HIGH_PRIORITY) {
                        println!("  [HighPriority] Fast-lane execution.");
                    }

                    // RequiresAffinity: pin to a pretend partition/worker lane.
                    let lane = work.get_id() % 4;
                    if behaviour.contains(Behaviour::REQUIRES_AFFINITY) {
                        println!("  [RequiresAffinity] Routing to lane {}.", lane);
                    }

                    match Self::simulate_by_execution_model(work, lane).await {
                        Ok(_) => {
                            if behaviour.contains(Behaviour::RETRYABLE) {
                                println!("  [Retryable] Succeeded on attempt {}/{}.", attempt, attempts);
                            }
                            else {
                                println!("  Completed.");
                            };
                        }
                        Err(err) => {
                            println!("  Attempt {}/{} failed: {}", attempt, attempts, err);

                            if attempt == attempts {
                                println!("  Giving up.");
                                return;
                            }

                            // Tiny exponential-ish backoff for the demo.
                            let backoff_ms = 50 * attempt * attempt;
                             sleep(Duration::from_millis(backoff_ms)).await;
                        }
                    };
                } => {}
            }
        }
    }

    async fn simulate_by_execution_model(work: &Work, lane: usize) -> io::Result<()> {
        let behaviour = work.get_behaviour();

        // Base pacing. Behaviours can tweak it.
        let mut step_delay_ms = 80;

        if behaviour.contains(Behaviour::LONG_RUNNING) {
            step_delay_ms += 160;
            println!("  [LongRunning] Slower steps.");
        }

        if behaviour.contains(Behaviour::RESOURCE_INTENSIVE) {
            println!("  [ResourceIntensive] Adding CPU work.");
        }

        // Scheduled: pretend we had to wait until a trigger time.
        if work.get_execution_model() == ExecutionModel::Scheduled {
            println!("  [Scheduled] Waiting for trigger...");
            sleep(Duration::from_millis(150)).await;
        }

        match work.get_execution_model() {
            ExecutionModel::OneOff => {
                Self::step("OneOff: run once", behaviour, step_delay_ms).await?;
            }
            ExecutionModel::Scheduled => {
                Self::step("Scheduled: execute job", behaviour, step_delay_ms).await?;
            }
            ExecutionModel::EventDriven => {
                Self::step(
                    "EventDriven: handle event payload",
                    behaviour,
                    step_delay_ms,
                )
                .await?;
            }
            ExecutionModel::Batch => {
                println!("  [Batch] Processing items...");
                for i in 1..=5 {
                    Self::step(
                        format!("Batch item {}/5", i).as_str(),
                        behaviour,
                        step_delay_ms,
                    )
                    .await?;
                }
            }
            ExecutionModel::Stream => {
                println!("  [Stream] Polling/consuming stream ticks...");
                for i in 1..=4 {
                    Self::step(
                        format!("Stream tick {}/4", i).as_str(),
                        behaviour,
                        step_delay_ms + 40,
                    )
                    .await?;
                }
            }
            ExecutionModel::Workflow => {
                println!("  [Workflow] Running steps (DAG-ish)...");
                Self::step("Step A: validate", behaviour, step_delay_ms).await?;
                Self::step("Step B: transform", behaviour, step_delay_ms + 20).await?;
                Self::step("Step C: persist", behaviour, step_delay_ms + 40).await?;
            }
            ExecutionModel::Actor => {
                println!(
                    "  [Actor] Handling partition key lane={} (stateful-ish).",
                    lane
                );
                Self::step("Actor turn: load state", behaviour, step_delay_ms).await?;
                Self::step("Actor turn: apply work", behaviour, step_delay_ms + 20).await?;
                Self::step("Actor turn: save state", behaviour, step_delay_ms + 40).await?;
            }
        };

        Ok(())
    }

    async fn step(label: &str, behaviour: Behaviour, delay_ms: usize) -> io::Result<()> {
        let mut rng = StdRng::from_rng(&mut rand::rng());
        let mut maybe_fail_transiently = || {
            if !behaviour.contains(Behaviour::RETRYABLE) {
                return Ok(());
            }

            // Fail sometimes (more often when "resource intensive") so retries are visible.
            let odds = if behaviour.contains(Behaviour::RESOURCE_INTENSIVE) {
                4
            } else {
                7
            }; // 1/4 or 1/7

            if rng.random_range(0..odds) == 0 {
                return Err(Error::new(
                    ErrorKind::Interrupted,
                    "Transient failure (simulated).",
                ));
            }

            Ok(())
        };

        let cpu_bump = |iterations: usize| {
            // ResourceIntensive: do a tiny CPU spin per step (demo only).
            let start = Instant::now();

            let mut x: u64 = 0;
            for i in 0..iterations as u64 {
                x = x.wrapping_mul(31) ^ i;
            }

            std::hint::black_box(x);

            let _elapsed = start.elapsed();
        };

        println!("  -> {}", label);

        if behaviour.contains(Behaviour::RESOURCE_INTENSIVE) {
            cpu_bump(25_000);
        }

        match maybe_fail_transiently() {
            Ok(_) => {
                sleep(Duration::from_millis(delay_ms as u64)).await;
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
