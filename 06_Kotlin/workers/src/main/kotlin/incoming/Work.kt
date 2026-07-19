package org.andreastme.langpermonth.incoming

import kotlin.random.Random

@ConsistentCopyVisibility
data class Work private constructor(
    val id: Int,
    val executionModel: ExecutionModel,
    val behaviour: Behaviour
) {
    companion object {
        fun create(id: Int) = Work(
            id = id,
            executionModel = pickRandomExecutionModel(),
            behaviour = pickRandomBehaviour()
        )

        private fun pickRandomExecutionModel(): ExecutionModel =
            ExecutionModel.from(Random.nextInt(0, ExecutionModel.entries.size))

        private fun pickRandomBehaviour(): Behaviour {
            var mask: ULong = 0u
            val singles = mutableListOf<Byte>()

            for (b in Behaviour.entries) {
                val bits = b.value
                if (bits == 0.toByte()) {
                    continue
                }

                // Only treat power-of-two values as "atomic" flags.
                if ((bits.toInt() and (bits - 1)) != 0) {
                    continue
                }

                singles.add(bits)

                if (Random.nextInt(2) == 0) {
                    mask = bits.toULong() or mask
                }
            }

            // Ensure we don't end up with "None" (0) too often.
            if (mask == 0.toULong() && singles.isNotEmpty()) {
                mask = singles[Random.nextInt(singles.size)].toULong()
            }

            return Behaviour.from(mask.toByte())
        }
    }
}
