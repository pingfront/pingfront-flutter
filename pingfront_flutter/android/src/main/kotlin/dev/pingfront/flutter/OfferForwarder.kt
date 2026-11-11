package dev.pingfront.flutter

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch

/**
 * Hands an offer tap to Dart so the paywall is never hidden. The presented chat is its own activity above the
 * Flutter activity, so a paywall Dart pushes as a route would sit under it: with [closesChat] on (the default), the
 * presented chat closes first and Dart is called once it is off screen. [closePresentedChat] returns at once when no
 * chat is presented (an embedded chat stays where it is). A second tap replaces a first one that is still waiting.
 */
internal class OfferForwarder<T>(
    private val scope: CoroutineScope,
    private val closePresentedChat: suspend () -> Unit,
    private val deliver: suspend (T) -> Unit,
) {
    var closesChat: Boolean = true
    private var job: Job? = null

    fun forward(request: T) {
        job?.cancel()
        job = scope.launch {
            if (closesChat) closePresentedChat()
            deliver(request)
        }
    }
}
