package dev.pingfront.flutter

import dev.pingfront.ConfigurationProblem
import dev.pingfront.LogLevel
import dev.pingfront.MomentResult
import dev.pingfront.OfferOutcome
import dev.pingfront.OfferRequest
import dev.pingfront.PingFrontEvent
import dev.pingfront.PingFrontException
import dev.pingfront.PingFrontModule
import dev.pingfront.look.ChatAppearance
import dev.pingfront.look.ChatTopic
import dev.pingfront.model.ColorScheme
import dev.pingfront.model.Corners
import dev.pingfront.model.Density
import dev.pingfront.model.Entitlement
import dev.pingfront.model.FontStyle
import dev.pingfront.model.HeaderStyle
import dev.pingfront.model.OfferSlot
import dev.pingfront.model.PersonSummary
import dev.pingfront.model.PingFrontColor
import dev.pingfront.model.StoreOffer
import dev.pingfront.model.Timestamps
import dev.pingfront.model.TopicSymbol
import dev.pingfront.reports.Reports
import java.time.Instant

/**
 * Converts between the Pigeon transport shapes and the native SDK's types. Enum values travel as the
 * Dart enum names; anything unknown maps to the SDK's fallback, never to an exception.
 */
internal object Mapping {
    // Dart to native

    private inline fun <reified T : Enum<T>> byName(name: String?): T? = name?.let { n -> enumValues<T>().firstOrNull { it.name.equals(n, ignoreCase = true) } }

    private fun color(message: ColorMessage?): PingFrontColor? = message?.let { PingFrontColor(it.light, it.dark) }

    fun applyAppearance(m: AppearanceMessage, a: ChatAppearance) {
        a.accent = color(m.accent)
        a.background = color(m.background)
        a.teamBubble = color(m.teamBubble)
        a.scheme = byName<ColorScheme>(m.scheme)
        a.font = byName<FontStyle>(m.font)
        a.corners = byName<Corners>(m.corners)
        a.density = byName<Density>(m.density)
        a.timestamps = byName<Timestamps>(m.timestamps)
        a.headerStyle = byName<HeaderStyle>(m.headerStyle)
        a.headerTitle = m.headerTitle
        a.headerMemberId = m.headerMemberId
        a.replyExpectation = m.replyExpectation
        a.showReplyExpectation = m.showsReplyExpectation
        a.showLocalTime = m.showsLocalTime
        a.showAvatars = m.showsAvatars
        a.showNames = m.showsNames
        a.showWelcomeFaces = m.showsWelcomeFaces
        a.welcomeTitle = m.welcomeTitle
        a.welcomeBody = m.welcomeBody
        a.composerPlaceholder = m.composerPlaceholder
        a.photos = m.allowsPhotos
        a.reports = m.allowsReports
        a.aiName = m.aiName
        m.useDynamicColor?.let { a.useDynamicColor = it }
    }

    private val presets: Map<String, ChatTopic> = listOf(
        ChatTopic.Billing, ChatTopic.Bug, ChatTopic.Idea, ChatTopic.Question, ChatTopic.Account,
        ChatTopic.Feedback, ChatTopic.Gift, ChatTopic.Restore, ChatTopic.Privacy,
    ).associateBy { it.id }

    fun topic(m: TopicMessage): ChatTopic {
        // A preset without a custom label keeps the SDK's translated label.
        val preset = presets[m.id]
        if (m.label == null && preset != null) return if (m.prefill == null) preset else preset.copy(prefill = dev.pingfront.model.LocalizedText.of(m.prefill))
        return ChatTopic(m.id, m.label ?: m.id, byName<TopicSymbol>(m.symbol) ?: TopicSymbol.Other, m.prefill)
    }

    /** Push and Billing are separate artifacts: found at runtime, so the plugin never forces Firebase or Play Billing on an app. */
    fun module(m: ModuleMessage): PingFrontModule? = when (m.id) {
        "reports" -> Reports(shake = m.shakeToReport ?: true, logTail = m.logTail ?: true)
        "push" -> optionalModule(Names.PUSH_MODULE, null, "push", "sh.pingfront:pingfront-push")
        "store" -> optionalModule(Names.BILLING_MODULE, m.products.orEmpty(), "store", "sh.pingfront:pingfront-billing")
        else -> Adapters.module(m.id, m.options.orEmpty())
    }

    private fun optionalModule(className: String, products: List<String>?, name: String, artifact: String): PingFrontModule? = try {
        val type = Class.forName(className)
        val instance = type.getField("INSTANCE").get(null)
        if (products == null) {
            instance as PingFrontModule
        } else {
            type.getMethod("invoke", List::class.java).invoke(instance, products) as PingFrontModule
        }
    } catch (_: ReflectiveOperationException) {
        android.util.Log.e(Names.LOG_TAG, "The $name module needs $artifact in your app's Gradle dependencies; it was skipped.")
        null
    }

    fun logLevel(name: String): LogLevel = byName<LogLevel>(name) ?: LogLevel.Info

    private fun instant(ms: Long?): Instant? = ms?.let(Instant::ofEpochMilli)

    fun entitlement(m: EntitlementMessage): Entitlement = Entitlement(
        state = byName<Entitlement.State>(m.state) ?: Entitlement.State.Unknown,
        productId = m.productId,
        renewsAt = instant(m.renewsAtMs),
        source = m.source?.let(Entitlement::Source),
        expiresAt = instant(m.expiresAtMs),
        gracePeriodEndsAt = instant(m.gracePeriodEndsAtMs),
    )

    fun slot(m: OfferSlotMessage): OfferSlot = OfferSlot(
        id = m.id,
        title = m.title,
        kind = byName<OfferSlot.Kind>(m.kind) ?: OfferSlot.Kind.Standard,
        available = m.available,
        products = m.products.map { OfferSlot.Product(it.id, it.price, it.period, it.trial) },
        source = m.source?.let(OfferSlot::Source),
    )

    /** Dart ints arrive as Int or Long and doubles as Double: the SDK takes them as they are. */
    fun momentValue(value: Any): Any = when (value) {
        is Int -> value.toLong()
        else -> value
    }

    /** FCM data is string to string; nested values (from an APNs-shaped map) are passed as their text. */
    fun fcmData(payload: Map<String, Any?>): Map<String, String> = payload.mapNotNull { (key, value) -> value?.let { key to it.toString() } }.toMap()

    // Native to Dart

    fun person(p: PersonSummary): PersonMessage = PersonMessage(p.id, p.level.name.lowercase(), p.name)

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    fun problemKind(kind: ConfigurationProblem.Kind): String = when (kind) {
        is ConfigurationProblem.Kind.InvalidKey -> "invalidKey"
        ConfigurationProblem.Kind.MissingKey -> "missingKey"
        ConfigurationProblem.Kind.UnknownKey -> "unknownKey"
        ConfigurationProblem.Kind.AppPaused -> "appPaused"
        ConfigurationProblem.Kind.Option -> "option"
        else -> "unknown"
    }

    fun problem(p: ConfigurationProblem): ProblemMessage = ProblemMessage(problemKind(p.kind), p.message, p.disablesSdk)

    private fun storeOffer(o: StoreOffer): StoreOfferMessage = StoreOfferMessage(o.kind.name.lowercase(), o.id, o.productId, o.basePlanId, o.offerId)

    private fun slotMessage(s: OfferSlot): OfferSlotMessage = OfferSlotMessage(
        s.id,
        s.title,
        s.kind.name.lowercase(),
        s.available,
        s.products.map { OfferProductMessage(it.id, it.price, it.period, it.trial) },
        s.source?.code,
    )

    fun offerRequest(r: OfferRequest): OfferRequestMessage =
        OfferRequestMessage(r.offerId, r.cardId, r.messageId, r.slot?.let(::slotMessage), r.storeOffer?.let(::storeOffer))

    private fun requestData(r: OfferRequest): Map<String, Any?> = buildMap {
        put("offerId", r.offerId)
        put("cardId", r.cardId)
        put("messageId", r.messageId)
        r.storeOffer?.let { o ->
            put("storeOffer", mapOf("kind" to o.kind.name.lowercase(), "id" to o.id, "productId" to o.productId, "basePlanId" to o.basePlanId, "offerId" to o.offerId))
        }
    }

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    fun momentResult(result: MomentResult): MomentResultMessage = when (result) {
        MomentResult.Delivered -> MomentResultMessage("delivered")
        MomentResult.HeldOut -> MomentResultMessage("heldOut")
        MomentResult.Ignored -> MomentResultMessage("ignored")
        MomentResult.InvalidName -> MomentResultMessage("invalidName")
        MomentResult.NotListened -> MomentResultMessage("notListened")
        MomentResult.Scheduled -> MomentResultMessage("scheduled")
        is MomentResult.OpenRequested -> MomentResultMessage("openRequested", presented = result.presented)
        is MomentResult.Failed -> MomentResultMessage("failed", errorCode = errorCode(result.error), errorMessage = result.error.message)
        // A result a newer SDK adds: passed through by name.
        else -> MomentResultMessage(result::class.simpleName?.replaceFirstChar { it.lowercase() } ?: "unknown")
    }

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    fun errorCode(e: PingFrontException): String = when (e) {
        is PingFrontException.Server -> e.error.code.raw
        is PingFrontException.Network -> "network"
        is PingFrontException.NotConfigured -> "not_configured"
        is PingFrontException.CoolingDown -> "cooling_down"
        is PingFrontException.InvalidInput -> "invalid_input"
        is PingFrontException.InvalidKey -> "invalid_key"
        is PingFrontException.InvalidResponse -> "invalid_response"
        is PingFrontException.StorageUnavailable -> "storage_unavailable"
        is PingFrontException.SessionChanged -> "session_changed"
        else -> "unexpected"
    }

    fun bridgeError(e: PingFrontException): BridgeError = BridgeError(errorCode(e), e.message ?: errorCode(e), null)

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    private fun outcome(o: OfferOutcome): Pair<String, String?> = when (o) {
        OfferOutcome.Purchased -> "purchased" to null
        OfferOutcome.Pending -> "pending" to null
        OfferOutcome.Cancelled -> "cancelled" to null
        OfferOutcome.Unavailable -> "unavailable" to null
        is OfferOutcome.Failed -> "failed" to o.failure.code
        else -> (o::class.simpleName?.replaceFirstChar { it.lowercase() } ?: "unknown") to null
    }

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    fun event(event: PingFrontEvent): EventMessage = when (event) {
        PingFrontEvent.ChatOpened -> EventMessage("chatOpened", emptyMap())
        PingFrontEvent.ChatClosed -> EventMessage("chatClosed", emptyMap())
        PingFrontEvent.ReportSent -> EventMessage("reportSent", emptyMap())
        PingFrontEvent.SessionRevoked -> EventMessage("sessionRevoked", emptyMap())
        is PingFrontEvent.UnreadChanged -> EventMessage("unreadChanged", mapOf("count" to event.count))
        is PingFrontEvent.MessageReceived -> with(event.message) {
            EventMessage("messageReceived", mapOf("id" to id, "authorName" to authorName, "preview" to preview, "isPing" to isPing, "isAi" to isAi))
        }
        is PingFrontEvent.SessionStarted -> with(event.person) {
            EventMessage("sessionStarted", mapOf("personId" to id, "level" to level.name.lowercase(), "name" to name))
        }
        is PingFrontEvent.IdentityProblemReported -> EventMessage("identityProblem", mapOf("problem" to identityProblem(event.problem)))
        is PingFrontEvent.OfferRequested -> EventMessage("offerRequested", mapOf("request" to requestData(event.request)))
        is PingFrontEvent.OfferCompleted -> {
            val (name, failure) = outcome(event.outcome)
            EventMessage("offerCompleted", mapOf("request" to requestData(event.request), "outcome" to name, "failure" to failure))
        }
        is PingFrontEvent.MessageSent -> with(event.message) {
            EventMessage("messageSent", mapOf("id" to id, "textLength" to textLength, "photoCount" to photoCount, "repliesToPing" to repliesToPing))
        }
        is PingFrontEvent.CardOpened -> with(event.card) {
            EventMessage("cardOpened", mapOf("kind" to kind.name, "cardId" to cardId, "messageId" to messageId))
        }
        is PingFrontEvent.LookChanged -> EventMessage("lookChanged", mapOf("revision" to event.revision, "draft" to event.draft))
        is PingFrontEvent.ConfigurationProblemFound -> with(event.problem) {
            EventMessage("configurationProblem", mapOf("kind" to problemKind(kind), "message" to message, "disablesSdk" to disablesSdk))
        }
        // An event a newer SDK adds: passed through by name, and Dart turns it into `PingFrontEvent.unknown`.
        else -> EventMessage(event::class.simpleName?.replaceFirstChar { it.lowercase() } ?: "unknown", emptyMap())
    }

    // The `else` branches keep working when a newer SDK adds a subtype at runtime, where an exhaustive
    // `when` would throw instead.
    @Suppress("REDUNDANT_ELSE_IN_WHEN")
    private fun identityProblem(problem: dev.pingfront.model.IdentityProblem): String = when (problem) {
        dev.pingfront.model.IdentityProblem.TokenInvalid -> "token_invalid"
        dev.pingfront.model.IdentityProblem.TokenExpired -> "token_expired"
        dev.pingfront.model.IdentityProblem.UserMismatch -> "user_mismatch"
        else -> "unknown"
    }
}
