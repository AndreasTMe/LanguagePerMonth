package org.andreastme.langpermonth

import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.andreastme.langpermonth.incoming.Work

fun main(args: Array<String>) {
    val job = SupervisorJob()

    Runtime.getRuntime().addShutdownHook(
        Thread {
            println("Shutdown requested. Cancelling...")
            job.cancel()
        }
    )

    runBlocking(job) {
        val configuration = Configuration.create(args)
        when (configuration) {
            is Configuration.Valid -> {
                println("Valid configuration received. Starting...")
            }

            Configuration.Invalid -> {
                println("Invalid configuration received. Shutting down...")
                return@runBlocking
            }
        }

        val channel = Channel<Work>(capacity = configuration.messageCount)

        launch {
            try {
                repeat(configuration.messageCount) { id ->
                    channel.send(Work.create(id))
                }
            } finally {
                channel.close()
            }
        }

        repeat(configuration.threadCount) {
            launch {
                val worker = Worker(channel)
                worker.execute()
            }
        }
    }

    println("Work completed. Shutting down...");
}
