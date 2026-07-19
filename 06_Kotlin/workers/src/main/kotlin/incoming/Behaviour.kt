package org.andreastme.langpermonth.incoming

@JvmInline
value class Behaviour private constructor(val value: Byte) {

    infix fun or(other: Behaviour): Behaviour =
        Behaviour((value.toInt() or other.value.toInt()).toByte())

    fun hasFlag(flag: Behaviour): Boolean =
        (value.toInt() and flag.value.toInt()) != 0

    companion object {
        val None = Behaviour(0)
        val HighPriority = Behaviour(1 shl 0)
        val LongRunning = Behaviour(1 shl 1)
        val ResourceIntensive = Behaviour(1 shl 2)
        val RequiresAffinity = Behaviour(1 shl 3)
        val Retryable = Behaviour(1 shl 4)
        val ExactlyOnce = Behaviour(1 shl 5)

        val entries = setOf<Behaviour>(
            None,
            HighPriority,
            LongRunning,
            ResourceIntensive,
            RequiresAffinity,
            Retryable,
            ExactlyOnce
        )

        fun from(value: Byte): Behaviour = Behaviour(value)
    }

    private constructor(value: Int) : this(value.toByte())
}