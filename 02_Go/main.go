package main

import (
	"context"
	"log"
	"os"
	"sync"
	"workers/incoming"
)

func main() {
	config, err := NewConfiguration(os.Args)
	if err != nil {
		log.Printf("%v. Shutting down...", err)
		return
	}

	log.Printf("Valid configuration received. Starting...")

	channel := make(chan *incoming.Work, config.messageCount)

	for i := 0; i < config.messageCount; i++ {
		channel <- incoming.NewWork(uint(i))
	}
	
	close(channel)

	ctx := context.Background()
	wg := sync.WaitGroup{}

	for i := 0; i < config.threadCount; i++ {
		worker := NewWorker(channel)
		wg.Go(func() {
			worker.Execute(ctx)
		})
	}
	wg.Wait()

	log.Printf("Work completed. Shutting down...")
}
