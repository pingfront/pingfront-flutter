package dev.pingfront.flutter

import dev.pingfront.LogEntry
import dev.pingfront.LogLevel
import dev.pingfront.TeamAction
import dev.pingfront.conversation.ConversationPhase
import dev.pingfront.conversation.ConversationState
import dev.pingfront.conversation.LiveState
import dev.pingfront.conversation.PendingMessage
import dev.pingfront.conversation.TimelineItem
import dev.pingfront.look.ResolvedLook
import dev.pingfront.model.Card
import dev.pingfront.model.Message
import dev.pingfront.model.MessagePart
import dev.pingfront.model.PingFrontColor
import dev.pingfront.model.SendPolicy
import dev.pingfront.model.TeamMember
import dev.pingfront.model.ThreadStatus
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

/**
 * Maps the look, the conversation, team actions and log lines to the Pigeon shapes. Messages and the team
 * travel as the wire's JSON (the SDK's own serializers), so Dart decodes them with the protocol's rules.
 */
internal object Snapshots {
    private val wire = Json {
        explicitNulls = false
        encodeDefaults = false
    }

    fun messagesJson(messages: List<Message>): String = wire.encodeToString(ListSerializer(Message.serializer()), messages)

    fun teamJson(team: List<TeamMember>): String = wire.encodeToString(ListSerializer(TeamMember.serializer()), team)

    // Logs

    fun logEntry(entry: LogEntry): LogEntryMessage = LogEntryMessage(
        level = when (entry.level) {
            LogLevel.Off -> "off"
            LogLevel.Error -> "error"
            LogLevel.Debug -> "debug"
            else -> "info"
        },
        message = entry.message,
        category = entry.category,
    )

    // Look

    private fun color(c: PingFrontColor): ColorMessage = ColorMessage(c.light.hex, c.dark.hex)

    private fun <T : Enum<T>> name(value: T): String = value.name.replaceFirstChar { it.lowercase() }

    fun look(l: ResolvedLook): LookMessage = LookMessage(
        appName = l.appName,
        appIconUrl = l.appIconUrl,
        appIconPng = l.appIcon?.bytes,
        accent = color(l.accent),
        onAccent = color(l.onAccent),
        background = color(l.background),
        teamBubble = color(l.teamBubble),
        text = color(l.text),
        muted = color(l.muted),
        scheme = name(l.scheme),
        font = name(l.font),
        corners = name(l.corners),
        density = name(l.density),
        headerStyle = name(l.headerStyle),
        headerMemberId = l.headerMemberId,
        headerTitle = l.headerTitle?.values,
        showsLocalTime = l.showLocalTime,
        showsReplyExpectation = l.showReplyExpectation,
        welcomeTitle = l.welcomeTitle?.values,
        welcomeBody = l.welcomeBody?.values,
        showsWelcomeFaces = l.showWelcomeFaces,
        topics = l.topics.map { LookTopicMessage(it.id, it.label?.values, name(it.symbol), it.prefill?.values) },
        composerPlaceholder = l.composerPlaceholder?.values,
        allowsPhotos = l.photos,
        allowsReports = l.reports,
        showsNames = l.showNames,
        showsAvatars = l.showAvatars,
        timestamps = name(l.timestamps),
        replyExpectation = l.replyExpectation?.values,
        aiName = l.aiName,
        teamJson = teamJson(l.team),
        isDraft = l.isDraft,
        revision = l.revision.toLong(),
        bubbleRadius = l.bubbleRadius.toLong(),
    )

    // Team actions

    fun teamAction(a: TeamAction): TeamActionMessage = TeamActionMessage(
        id = a.id,
        actionId = a.actionId,
        name = a.name,
        fields = a.fields,
        days = a.days?.toLong(),
        untilMs = a.until?.toEpochMilli(),
        ackRequired = a.ackRequired,
        createdAtMs = a.createdAt.toEpochMilli(),
        expiresAtMs = a.expiresAt.toEpochMilli(),
    )

    // Conversation

    private fun pending(p: PendingMessage): PendingMessageMessage = PendingMessageMessage(
        clientId = p.clientId,
        text = p.text,
        photos = p.photos.map { PendingPhotoMessage(it.width.toLong(), it.height.toLong(), it.bytes.toLong(), it.sha256, it.attachmentId) },
        createdAtMs = p.createdAt.toEpochMilli(),
        attempts = p.attempts.toLong(),
        state = name(p.state),
        failure = p.failure,
        heldFor = p.heldFor?.code,
    )

    // The `else` branches keep working when a newer SDK adds a subtype at runtime.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    private fun timelineItem(item: TimelineItem): TimelineItemMessage {
        val (kind, id) = when (val content = item.content) {
            is TimelineItem.Content.Delivered -> "message" to content.message.id
            is TimelineItem.Content.Pending -> "pending" to content.message.clientId
            else -> "unknown" to item.id
        }
        return TimelineItemMessage(
            id = item.id,
            contentKind = kind,
            contentId = id,
            side = name(item.side),
            startsGroup = item.startsGroup,
            endsGroup = item.endsGroup,
            startsPing = item.startsPing,
            isAi = item.isAi,
            authorName = item.authorName,
            dateMs = item.date.toEpochMilli(),
            startsTimeSection = item.startsTimeSection,
        )
    }

    // The `else` branches keep working when a newer SDK adds a subtype at runtime.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    fun conversation(s: ConversationState, draft: String, insertion: String?): ConversationMessage {
        val (phase, failure) = when (val p = s.phase) {
            ConversationPhase.Idle -> "idle" to null
            ConversationPhase.Loading -> "loading" to null
            ConversationPhase.Ready -> "ready" to null
            // Android reports only whether the device looked offline.
            is ConversationPhase.Failed -> "failed" to (if (p.offline) "network" else "unexpected")
            else -> "unknown" to null
        }
        var retryMs: Long? = null
        var liveOffline = false
        val live = when (val l = s.live) {
            LiveState.Stopped -> "stopped"
            LiveState.Connecting -> "connecting"
            LiveState.Live -> "live"
            is LiveState.Waiting -> {
                retryMs = l.retryIn.inWholeMilliseconds
                liveOffline = l.offline
                "waiting"
            }
            else -> "unknown"
        }
        val policy = s.policy
        return ConversationMessage(
            phase = phase,
            failureCode = failure,
            messagesJson = messagesJson(s.messages),
            pending = s.pending.map(::pending),
            timeline = s.timeline.map(::timelineItem),
            hasOlder = s.hasOlder,
            isLoadingOlder = s.isLoadingOlder,
            teamJson = teamJson(s.team),
            replyExpectation = s.replyExpectation,
            canSend = policy.canSend,
            closedReason = (policy as? SendPolicy.Closed)?.reason?.code,
            status = when (s.status) {
                ThreadStatus.Open -> "open"
                ThreadStatus.Resolved -> "resolved"
                else -> "unknown"
            },
            typingIsAi = s.typing?.isAi,
            typingName = s.typing?.name,
            live = live,
            liveRetryInMs = retryMs,
            liveOffline = liveOffline,
            teamReadSeq = s.teamReadSeq.toLong(),
            isOffline = s.isOffline,
            isServerUnreachable = s.isServerUnreachable,
            draft = draft,
            composerInsertion = insertion,
            coolingDown = s.coolingDown.map { it.code },
            // iOS only (Ask to Buy); Play shows its own pending state.
            awaitingApproval = emptyList(),
        )
    }

    /** A message and one of its cards, by id. */
    fun card(s: ConversationState, messageId: String, cardId: String): Pair<Message, Card>? {
        val message = s.messages.firstOrNull { it.id == messageId } ?: return null
        val card = message.parts.filterIsInstance<MessagePart.CardPart>().firstOrNull { it.card.id == cardId }?.card ?: return null
        return message to card
    }

    fun notFound(what: String): BridgeError = BridgeError("invalid_input", "No $what with this id is in the conversation; it may have changed.", null)
}
