package dev.pingfront.flutter

import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive

/**
 * A link the native chat hands to Dart's `onLink`. The native SDK has already checked the link card URL rule
 * (https://pingfront.sh/docs/chat-links), so a refused URL never gets here. [forward] waits for Dart's answer and returns it:
 * the SDK caps the wait at 10 seconds and cancels it then, opens a declined link the way the chat opens it, and
 * replaces a message link still waiting when a newer one is tapped, so the plugin keeps no link logic or timer of its
 * own. A timely `true` closes the presented chat; an answer after the cap is ignored.
 */
internal class LinkForwarder(
    private val askDart: suspend (String) -> Boolean,
    private val closeChat: () -> Unit,
) {
    suspend fun forward(url: String): Boolean {
        val handled = askDart(url)
        // Past the cap the SDK has already counted the link as declined: a late answer closes nothing.
        currentCoroutineContext().ensureActive()
        if (handled) closeChat()
        return handled
    }
}
