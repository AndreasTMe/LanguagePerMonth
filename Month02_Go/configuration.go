package main

import (
	"fmt"
	"strconv"
)

const messageCountArg = "--message-count"
const threadCountArg = "--thread-count"

type Configuration struct {
	messageCount int
	threadCount  int
}

func NewConfiguration(args []string) (*Configuration, error) {
	if len(args) < 4 {
		return nil, fmt.Errorf("invalid input. Pass required arguments: '%s', '%s'", messageCountArg, threadCountArg)
	}

	var messageCount int = 0
	var threadCount int = 0

	for i := 1; i < len(args) && i+1 < len(args); i += 2 {
		switch args[i] {
		case messageCountArg:
			if num, err := strconv.ParseUint(args[i+1], 10, 32); err == nil {
				messageCount = int(num)
			}
			continue
		case threadCountArg:
			if num, err := strconv.ParseUint(args[i+1], 10, 32); err == nil {
				threadCount = int(num)
			}
			continue
		default:
			continue
		}
	}

	return &Configuration{
		messageCount: messageCount,
		threadCount:  threadCount,
	}, nil
}
