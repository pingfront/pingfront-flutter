package dev.pingfront.flutter

import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class SharedRequestTest {
    @Test
    fun concurrentCallersShareOnePromptAndAllGetItsAnswer() = runTest {
        var prompts = 0
        var answer = CompletableDeferred<Boolean>()
        val request = SharedRequest<Boolean>(backgroundScope)
        val prompt: suspend () -> Boolean = {
            prompts += 1
            answer.await()
        }
        val first = async { request.await(prompt) }
        val second = async { request.await(prompt) }
        runCurrent()
        assertEquals(1, prompts, "the second call waits for the first prompt instead of replacing it")
        answer.complete(true)
        assertTrue(first.await())
        assertTrue(second.await())
        // Once answered, the next call prompts again.
        answer = CompletableDeferred()
        val third = async { request.await(prompt) }
        runCurrent()
        assertEquals(2, prompts)
        answer.complete(false)
        assertEquals(false, third.await())
    }

    @Test
    fun aCancelledCallerLeavesThePromptForTheOthers() = runTest {
        val answer = CompletableDeferred<Boolean>()
        val request = SharedRequest<Boolean>(backgroundScope)
        val first = async { request.await { answer.await() } }
        val second = async { request.await { answer.await() } }
        runCurrent()
        first.cancel()
        answer.complete(true)
        assertTrue(second.await())
    }

    @Test
    fun aRequestThatAnswersAtOnceIsNotKept() = runTest {
        var prompts = 0
        val request = SharedRequest<Int>(backgroundScope)
        assertEquals(1, request.await { ++prompts })
        assertEquals(2, request.await { ++prompts })
    }
}
