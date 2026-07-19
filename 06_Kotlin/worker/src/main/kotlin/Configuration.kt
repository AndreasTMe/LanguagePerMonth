package org.andreastme.langpermonth

private const val MessageCountArg = "--message-count"
private const val ThreadCountArg = "--thread-count"

sealed interface Configuration {
    companion object {
        fun create(args: Array<String>): Configuration {
            if (args.size < 4) {
                println("Invalid input. Pass required arguments: '$MessageCountArg', '$ThreadCountArg'.")
                return Invalid
            }

            var messageCount = 0
            var threadCount = 0

            for (i in args.indices step 2) {
                when (args[i]) {
                    MessageCountArg -> messageCount = args[i + 1].toIntOrNull() ?: 0
                    ThreadCountArg -> threadCount = args[i + 1].toIntOrNull() ?: 0
                }
            }

            return if (messageCount > 0 && threadCount > 0) Valid(messageCount, threadCount) else Invalid
        }
    }

    data class Valid(val messageCount: Int, val threadCount: Int) : Configuration
    data object Invalid : Configuration
}