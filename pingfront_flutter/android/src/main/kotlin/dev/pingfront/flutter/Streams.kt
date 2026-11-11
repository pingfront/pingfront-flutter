package dev.pingfront.flutter

import dev.pingfront.PingFront
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.conflate
import kotlinx.coroutines.launch

/** Forwards `PingFront.events` while Dart listens. */
internal class EventStream(private val scope: CoroutineScope) : EventsStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<EventMessage>) {
        job?.cancel()
        job = scope.launch { PingFront.events.collect { sink.success(Mapping.event(it)) } }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}

/** Sends `PingFront.unreadCount` (a `StateFlow`) to Dart: the current value, then changes. */
internal class UnreadStream(private val scope: CoroutineScope) : UnreadCountsStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<Long>) {
        job?.cancel()
        job = scope.launch { PingFront.unreadCount.collect { sink.success(it.toLong()) } }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}

/** Keeps the team actions Dart received until Dart answers them. Main thread only. */
internal class TeamActionRegistry {
    private val waiting = mutableMapOf<String, dev.pingfront.TeamAction>()

    fun keep(action: dev.pingfront.TeamAction) {
        waiting[action.id] = action
    }

    fun take(id: String): dev.pingfront.TeamAction? = waiting.remove(id)
}

/** Forwards `PingFront.teamActions` while Dart listens; actions not answered yet are replayed to each listen. */
internal class TeamActionStream(private val scope: CoroutineScope, private val registry: TeamActionRegistry) : TeamActionsStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<TeamActionMessage>) {
        job?.cancel()
        job = scope.launch {
            PingFront.teamActions.collect {
                registry.keep(it)
                sink.success(Snapshots.teamAction(it))
            }
        }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}

/** Sends the conversation (state, draft and composer insertion) to Dart: the current snapshot, then changes. */
internal class ConversationStream(private val scope: CoroutineScope) : ConversationStatesStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<ConversationMessage>) {
        job?.cancel()
        val conversation = PingFront.conversation
        job = scope.launch {
            combine(conversation.state, conversation.draft, conversation.composerInsertion, Snapshots::conversation)
                .conflate()
                .collect { sink.success(it) }
        }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}

/** Sends `PingFront.look` to Dart: the current value, then changes. */
internal class LookStream(private val scope: CoroutineScope) : LooksStreamHandler() {
    private var job: Job? = null

    override fun onListen(p0: Any?, sink: PigeonEventSink<LookMessage>) {
        job?.cancel()
        job = scope.launch { PingFront.look.collect { sink.success(Snapshots.look(it)) } }
    }

    override fun onCancel(p0: Any?) {
        job?.cancel()
        job = null
    }
}
