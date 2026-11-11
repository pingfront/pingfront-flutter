package dev.pingfront.flutter

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.withContext
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class LinkForwarderTest {
    @Test
    fun dartsAnswerIsReturnedAndOnlyAHandledLinkClosesTheChat() = runTest {
        val log = mutableListOf<String>()
        var dart = false
        val forwarder = LinkForwarder(
            askDart = {
                log += "dart $it"
                dart
            },
            closeChat = { log += "close" },
        )
        assertFalse(forwarder.forward("myapp://settings"), "declined: the SDK opens it, the plugin doesn't")
        assertEquals(listOf("dart myapp://settings"), log)
        log.clear()
        dart = true
        assertTrue(forwarder.forward("myapp://settings"))
        assertEquals(listOf("dart myapp://settings", "close"), log)
    }

    @Test
    fun theAnswerWaitsForDartAndACancelledWaitClosesNothing() = runTest {
        val log = mutableListOf<String>()
        val dart = CompletableDeferred<Boolean>()
        // A platform channel reply doesn't stop when the caller is cancelled: it arrives in its own time.
        val forwarder = LinkForwarder(askDart = { withContext(NonCancellable) { dart.await() } }, closeChat = { log += "close" })
        val waiting = async { forwarder.forward("https://a.example") }
        runCurrent()
        assertTrue(waiting.isActive, "still waiting for Dart")
        // The SDK cancels the handler at its 10-second cap (or for a newer tap, or logout).
        waiting.cancel()
        dart.complete(true)
        runCurrent()
        assertEquals(emptyList(), log, "a late true never closes the chat")
    }
}
