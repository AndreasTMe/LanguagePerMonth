package incoming

import (
	"fmt"
	"strings"
)

type ExecutionModel uint8

const (
	ExecutionModelOneOff      = iota // Single fire-and-forget unit
	ExecutionModelScheduled          // Time-triggered (cron/delayed)
	ExecutionModelEventDriven        // Triggered by domain/infrastructure event
	ExecutionModelBatch              // Large dataset processing
	ExecutionModelStream             // Long-lived continuous processing
	ExecutionModelWorkflow           // DAG / multistep orchestration
	ExecutionModelActor              // Key-partitioned stateful unit
)

func (e ExecutionModel) String() string {
	// Keep a stable, readable order in the output.
	type namedBit struct {
		bit  ExecutionModel
		name string
	}
	known := []namedBit{
		{ExecutionModelOneOff, "OneOff"},
		{ExecutionModelScheduled, "Scheduled"},
		{ExecutionModelEventDriven, "EventDriven"},
		{ExecutionModelBatch, "Batch"},
		{ExecutionModelStream, "Stream"},
		{ExecutionModelWorkflow, "Workflow"},
		{ExecutionModelActor, "Actor"},
	}

	var parts []string
	remaining := e

	for _, kb := range known {
		if remaining&kb.bit != 0 {
			parts = append(parts, kb.name)
			remaining &^= kb.bit // clear that bit
		}
	}

	// If there are unknown bits set, include them explicitly.
	if remaining != 0 {
		parts = append(parts, fmt.Sprintf("ExecutionModel(%d)", uint8(remaining)))
	}

	return strings.Join(parts, " | ")
}

var allExecutionModels = []ExecutionModel{
	ExecutionModelOneOff,
	ExecutionModelScheduled,
	ExecutionModelEventDriven,
	ExecutionModelBatch,
	ExecutionModelStream,
	ExecutionModelWorkflow,
	ExecutionModelActor,
}

func GetExecutionModels() []ExecutionModel {
	return allExecutionModels
}
