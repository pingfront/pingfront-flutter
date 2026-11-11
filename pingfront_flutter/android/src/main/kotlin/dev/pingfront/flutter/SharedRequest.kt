package dev.pingfront.flutter

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.async

/**
 * One request at a time, shared by every caller that asks while it runs: the notification permission prompt, whose
 * activity result key is fixed, so a second prompt would replace the first and leave its caller waiting forever.
 * [await] starts its block in [scope] when nothing is pending and otherwise waits for the pending one (its own block
 * is then unused); a caller that is cancelled stops waiting without cancelling it for the others. Main thread only
 * (Pigeon calls arrive there).
 */
internal class SharedRequest<T>(private val scope: CoroutineScope) {
    private var pending: Deferred<T>? = null

    suspend fun await(block: suspend () -> T): T {
        val running = pending ?: scope.async(start = CoroutineStart.LAZY) {
            try {
                block()
            } finally {
                pending = null
            }
        }.also { pending = it }
        return running.await()
    }
}
