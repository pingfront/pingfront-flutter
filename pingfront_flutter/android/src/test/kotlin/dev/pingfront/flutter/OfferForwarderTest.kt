package dev.pingfront.flutter

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals

@OptIn(ExperimentalCoroutinesApi::class)
class OfferForwarderTest {
    /** A presented chat that closes when [hidden] completes, or none. An embedded chat is never "presented". */
    private class Harness(scope: TestScope, var presented: Boolean) {
        val log = mutableListOf<String>()
        val hidden = CompletableDeferred<Unit>()
        val forwarder = OfferForwarder<String>(
            scope = scope,
            closePresentedChat = {
                if (presented) {
                    log += "close"
                    hidden.await()
                    log += "hidden"
                }
            },
            deliver = { log += "deliver $it" },
        )
    }

    @Test
    fun closesThePresentedChatAndWaitsBeforeDartSeesTheOffer() = runTest {
        val h = Harness(this, presented = true)
        h.forwarder.forward("pro_yearly")
        runCurrent()
        assertEquals(listOf("close"), h.log, "Dart is not called while the chat is still on screen")
        h.hidden.complete(Unit)
        runCurrent()
        assertEquals(listOf("close", "hidden", "deliver pro_yearly"), h.log)
    }

    @Test
    fun embeddedOnlyDeliversAtOnce() = runTest {
        // An embedded chat makes the SDK's chat visible, but nothing is presented: no wait.
        val h = Harness(this, presented = false)
        h.forwarder.forward("pro_yearly")
        runCurrent()
        assertEquals(listOf("deliver pro_yearly"), h.log)
        assertEquals(0L, testScheduler.currentTime, "no timeout was waited for")
    }

    @Test
    fun keepsTheChatWhenDartOptedOut() = runTest {
        val h = Harness(this, presented = true)
        h.forwarder.closesChat = false
        h.forwarder.forward("pro_yearly")
        runCurrent()
        assertEquals(listOf("deliver pro_yearly"), h.log)
    }

    @Test
    fun aSecondTapReplacesOneStillWaiting() = runTest {
        val h = Harness(this, presented = true)
        h.forwarder.forward("first")
        runCurrent()
        h.forwarder.forward("second")
        runCurrent()
        h.hidden.complete(Unit)
        runCurrent()
        assertEquals(listOf("close", "close", "hidden", "deliver second"), h.log)
    }
}
