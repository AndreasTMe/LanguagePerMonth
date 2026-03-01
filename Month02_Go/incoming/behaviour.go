package incoming

import "fmt"

type Behaviour uint8

const (
	BehaviourNone Behaviour = 0

	BehaviourHighPriority Behaviour = 1 << (iota - 1)
	BehaviourLongRunning
	BehaviourResourceIntensive
	BehaviourRequiresAffinity
	BehaviourRetryable
	BehaviourExactlyOnce
)

func (b Behaviour) HasFlag(other Behaviour) bool {
	return b&other == other
}

func (b Behaviour) String() string {
	switch b {
	case BehaviourNone:
		return "None"
	case BehaviourHighPriority:
		return "HighPriority"
	case BehaviourLongRunning:
		return "LongRunning"
	case BehaviourResourceIntensive:
		return "ResourceIntensive"
	case BehaviourRequiresAffinity:
		return "RequiresAffinity"
	case BehaviourRetryable:
		return "Retryable"
	case BehaviourExactlyOnce:
		return "ExactlyOnce"
	default:
		return fmt.Sprintf("%d", int(b))
	}
}

var allBehaviours = []Behaviour{
	BehaviourHighPriority,
	BehaviourLongRunning,
	BehaviourResourceIntensive,
	BehaviourRequiresAffinity,
	BehaviourRetryable,
	BehaviourExactlyOnce,
}

func GetBehaviours() []Behaviour {
	return allBehaviours
}
