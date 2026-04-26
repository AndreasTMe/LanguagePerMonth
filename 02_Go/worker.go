package main

import (
	"context"
	"fmt"
	"log"
	"math/rand"
	"sync"
	"time"
	"workers/incoming"
)

type concurrentSet[T comparable] struct {
	mu sync.Mutex
	m  map[T]struct{}
}

func (s *concurrentSet[T]) tryAdd(v T) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if _, exists := s.m[v]; exists {
		return false
	}

	s.m[v] = struct{}{}
	return true
}

var processed = &concurrentSet[uint]{
	m: make(map[uint]struct{}),
}

type Worker struct {
	reader <-chan *incoming.Work
}

func NewWorker(reader <-chan *incoming.Work) *Worker {
	return &Worker{
		reader: reader,
	}
}

func (w *Worker) Execute(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			return
		case work, ok := <-w.reader:
			if !ok {
				return
			}

			log.Printf(
				"Working on item %d | Model=%v | Behaviour=%v",
				work.GetId(),
				work.GetExecutionModel(),
				work.GetBehaviour())

			w.simulate(work, ctx)

			log.Printf("Done work %d.", work.GetId())
		}
	}
}

func (w *Worker) simulate(work *incoming.Work, ctx context.Context) {
	behaviour := work.GetBehaviour()
	// Exactly-once: skip duplicates (demo-level, in-memory only).
	if behaviour.HasFlag(incoming.BehaviourExactlyOnce) && !processed.tryAdd(work.GetId()) {
		log.Printf("  [ExactlyOnce] Work %d already processed -> skipping.", work.GetId())
		return
	}

	var attempts int
	if behaviour.HasFlag(incoming.BehaviourRetryable) {
		attempts = 3
	} else {
		attempts = 1
	}

	for attempt := 1; attempt <= attempts; attempt++ {
		select {
		case <-ctx.Done():
			log.Printf("  Work cancelled")
			return
		default:
			// HighPriority: less "queueing"/overhead before work begins.
			if behaviour.HasFlag(incoming.BehaviourHighPriority) {
				log.Printf("  [HighPriority] Fast-lane execution.")
			}

			// RequiresAffinity: pin to a pretend partition/worker lane.
			lane := work.GetId() % 4
			if behaviour.HasFlag(incoming.BehaviourRequiresAffinity) {
				log.Printf("  [RequiresAffinity] Routing to lane %d.", lane)
			}

			if err := w.simulateByExecutionModel(work, lane); err != nil {
				log.Printf("  Attempt %d/%d failed: %v", attempt, attempts, err)

				if attempt == attempts {
					log.Printf("  Giving up.")
					return
				}

				// Tiny exponential-ish backoff for the demo.
				backoff := time.Duration(50 * attempt * attempt)
				time.Sleep(backoff * time.Millisecond)
				continue
			}

			if behaviour.HasFlag(incoming.BehaviourRetryable) {
				log.Printf("  [Retryable] Succeeded on attempt %d/%d.", attempt, attempts)
			} else {
				log.Printf("  Completed.")
			}
		}
	}
}

func (w *Worker) simulateByExecutionModel(work *incoming.Work, lane uint) error {
	behaviour := work.GetBehaviour()

	// Base pacing. Behaviours can tweak it.
	stepDelayMs := 80

	if behaviour.HasFlag(incoming.BehaviourLongRunning) {
		stepDelayMs += 160
		log.Printf("  [LongRunning] Slower steps.")
	}

	if behaviour.HasFlag(incoming.BehaviourResourceIntensive) {
		log.Printf("  [ResourceIntensive] Adding CPU work.")
	}

	// Scheduled: pretend we had to wait until a trigger time.
	if work.GetExecutionModel() == incoming.ExecutionModelScheduled {
		log.Printf("  [Scheduled] Waiting for trigger...")
		time.Sleep(150 * time.Millisecond)
	}

	switch work.GetExecutionModel() {
	case incoming.ExecutionModelOneOff:
		if err := step("OneOff: run once", behaviour, stepDelayMs); err != nil {
			return err
		}
		break
	case incoming.ExecutionModelScheduled:
		if err := step("Scheduled: execute job", behaviour, stepDelayMs); err != nil {
			return err
		}
		break
	case incoming.ExecutionModelEventDriven:
		if err := step("EventDriven: handle event payload", behaviour, stepDelayMs); err != nil {
			return err
		}
		break
	case incoming.ExecutionModelBatch:
		log.Printf("  [Batch] Processing items...")
		for i := 1; i <= 5; i++ {
			if err := step(fmt.Sprintf("Batch item %d/5", i), behaviour, stepDelayMs); err != nil {
				return err
			}
		}
		break
	case incoming.ExecutionModelStream:
		log.Printf("  [Stream] Polling/consuming stream ticks...")
		for tick := 1; tick <= 4; tick++ {
			if err := step(fmt.Sprintf("Stream tick %d/5", tick), behaviour, stepDelayMs+40); err != nil {
				return err
			}
		}
		break
	case incoming.ExecutionModelWorkflow:
		log.Printf("  [Workflow] Running steps (DAG-ish)...")
		if err := step("Step A: validate", behaviour, stepDelayMs); err != nil {
			return err
		}
		if err := step("Step B: transform", behaviour, stepDelayMs+20); err != nil {
			return err
		}
		if err := step("Step C: persist", behaviour, stepDelayMs+40); err != nil {
			return err
		}
		break
	case incoming.ExecutionModelActor:
		log.Printf("  [Actor] Handling partition key lane=%d (stateful-ish).", lane)
		if err := step("Actor turn: load state", behaviour, stepDelayMs); err != nil {
			return err
		}
		if err := step("Actor turn: apply work", behaviour, stepDelayMs+20); err != nil {
			return err
		}
		if err := step("Actor turn: save state", behaviour, stepDelayMs+40); err != nil {
			return err
		}
		break
	default:
		if err := step("Unknown model: fallback", behaviour, stepDelayMs); err != nil {
			return err
		}
		break
	}

	return nil
}

func step(label string, behaviour incoming.Behaviour, delayMs int) error {
	log.Printf("  -> %s", label)
	if behaviour.HasFlag(incoming.BehaviourResourceIntensive) {
		cpuBump(25_000)
	}

	if err := maybeFailTransiently(behaviour); err != nil {
		return err
	}

	time.Sleep(time.Duration(delayMs) * time.Millisecond)
	return nil
}

// ResourceIntensive: do a tiny CPU spin per step (demo only).
func cpuBump(iterations int) {
	start := time.Now()

	x := 0
	for i := 0; i < iterations; i++ {
		x = (x * 31) ^ i
	}

	_ = x // prevent optimization

	_ = time.Since(start)
}

// Random transient failure for Retryable demos.
func maybeFailTransiently(behaviour incoming.Behaviour) error {
	if !behaviour.HasFlag(incoming.BehaviourRetryable) {
		return nil
	}

	// Fail sometimes (more often when "resource intensive") so retries are visible.
	var odds int // 1/4 or 1/7
	if behaviour.HasFlag(incoming.BehaviourResourceIntensive) {
		odds = 4
	} else {
		odds = 7
	}

	if rand.Intn(odds) == 0 {
		return fmt.Errorf("transient failure (simulated)")
	}

	return nil
}
