package incoming

import (
	"math/rand"
)

type Work struct {
	id             uint
	executionModel ExecutionModel
	behaviour      Behaviour
}

func NewWork(id uint) *Work {
	return &Work{
		id:             id,
		executionModel: pickRandomExecutionModel(),
		behaviour:      pickRandomBehaviour(),
	}
}

func (w *Work) GetId() uint {
	return w.id
}

func (w *Work) GetExecutionModel() ExecutionModel {
	return w.executionModel
}

func (w *Work) GetBehaviour() Behaviour {
	return w.behaviour
}

func pickRandomExecutionModel() ExecutionModel {
	var executionModels = GetExecutionModels()
	return executionModels[rand.Intn(len(executionModels))]
}

func pickRandomBehaviour() Behaviour {
	var mask uint8 = 0
	singles := make([]uint8, 0, 8)

	for _, b := range GetBehaviours() {
		bits := uint8(b)

		if bits == 0 {
			continue
		}

		// Only treat power-of-two values as "atomic" flags.
		if bits&(bits-1) != 0 {
			continue
		}

		singles = append(singles, bits)

		if rand.Intn(2) == 0 {
			mask |= bits
		}
	}

	// Ensure we don't end up with "NONE" (0) too often.
	if mask == 0 && len(singles) > 0 {
		mask = singles[rand.Intn(len(singles))]
	}

	return Behaviour(mask)
}
