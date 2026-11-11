package dev.pingfront.flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import dev.pingfront.IdentityToken
import dev.pingfront.LogHandler
import dev.pingfront.OfferRequest
import dev.pingfront.PingFront
import dev.pingfront.PingFrontException
import dev.pingfront.RateScope
import dev.pingfront.conversation.PendingMessage
import dev.pingfront.model.Card
import dev.pingfront.model.MessagePart
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * The host API: every Dart call lands here on the main thread and goes straight to `PingFront`. Pigeon's generated
 * code starts each call in a coroutine of its own, so every call that can wait (erase, export, prepare, reports,
 * moments, the self-check, closing the chat) runs inside [scope], which ends when the engine detaches: nothing the
 * bridge started outlives it (review AN-22).
 */
internal class Bridge(
    private val context: Context,
    private val flutterApi: PingFrontFlutterApi,
    private val teamActions: TeamActionRegistry,
    private val results: ActivityResults,
) : PingFrontHostApi {
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** The embedded chats, for their padding. */
    var chatViews: ChatViewFactory? = null

    private val offers = OfferForwarder<OfferRequest>(
        scope = scope,
        // Only the presented chat closes for an offer, whenever it shows; an embedded chat stays and adds no wait.
        closePresentedChat = { PingFront.closeChatAndWait() },
        deliver = { request ->
            try {
                flutterApi.onOffer(Mapping.offerRequest(request))
            } catch (_: BridgeError) {
                // The Dart side is gone (hot restart); nothing can show the offer.
            }
        },
    )
    private val links = LinkForwarder(
        askDart = { url ->
            try {
                flutterApi.onLink(url)
            } catch (_: BridgeError) {
                false // The Dart side is gone (hot restart).
            }
        },
        closeChat = { PingFront.closeChat() },
    )

    fun close() {
        PingFront.onOffer = null
        PingFront.onLink = null
        PingFront.onScreen = null
        scope.cancel()
    }

    // Setup

    override suspend fun configure(request: ConfigureRequest) {
        val modules = request.modules.mapNotNull(Mapping::module)
        PingFront.configure(context, request.appKey) {
            appearance { Mapping.applyAppearance(request.appearance, this) }
            request.topics?.let { topics(it.map(Mapping::topic)) }
            request.baseUrl?.let { baseUrl = it }
            logLevel = Mapping.logLevel(request.logLevel)
            presentsChatForMoments = request.presentsChatForMoments
            use(*modules.toTypedArray())
            request.language?.let { language = it }
            if (request.forwardsLogs) logHandler = logForwarder()
            // PF-Wrapper on every request: flutter/<this plugin's version>.
            @OptIn(dev.pingfront.InternalPingFrontApi::class)
            wrapper("flutter", request.wrapperVersion)
        }
        apply(request.handlesOffers, request.closesChatForOffers, request.handlesLinks)
    }

    /** The SDK logs from any thread; each line reaches Dart on the main thread, and nothing once the engine is gone. */
    private fun logForwarder() = LogHandler { entry ->
        val message = Snapshots.logEntry(entry)
        scope.launch {
            try {
                flutterApi.onLog(message)
            } catch (_: BridgeError) {
                // The Dart side is gone (hot restart); the line is in logcat anyway.
            }
        }
    }

    // Saved links (https://pingfront.sh/docs/offers#saved-links)

    override suspend fun registerScreens(screens: List<AppScreenMessage>) {
        PingFront.registerScreens(screens.map { dev.pingfront.AppScreen(it.id, it.title) })
    }

    override suspend fun setScreenHandler(enabled: Boolean) {
        PingFront.onScreen = if (enabled) ::forwardScreen else null
    }

    /**
     * The tap waits for Dart's answer. The SDK caps the wait at 10 seconds and cancels this handler then, so a late
     * answer neither counts nor closes the chat; a timely `true` closes the presented chat, as a handled link does.
     */
    private suspend fun forwardScreen(screen: dev.pingfront.model.LinkScreen): Boolean {
        val opened = try {
            flutterApi.onScreen(LinkScreenMessage(screen.id, screen.params))
        } catch (_: BridgeError) {
            false // The Dart side is gone (hot restart).
        }
        if (opened) PingFront.closeChat()
        return opened
    }

    override suspend fun setHandlers(handlesOffers: Boolean, closesChatForOffers: Boolean, handlesLinks: Boolean) {
        apply(handlesOffers, closesChatForOffers, handlesLinks)
    }

    override suspend fun state(): StateMessage = StateMessage(
        isConfigured = PingFront.isConfigured.value,
        unreadCount = PingFront.unreadCount.value.toLong(),
        isChatVisible = PingFront.isChatVisible.value,
        isTestDevice = PingFront.isTestDevice.value,
        person = PingFront.person.value?.let(Mapping::person),
        configurationProblem = PingFront.configurationProblem.value?.let(Mapping::problem),
    )

    // Identity

    override suspend fun identify(userId: String, name: String?, email: String?) = PingFront.identify(userId, name, email)

    override suspend fun identifyWithToken(token: String) = PingFront.identify(IdentityToken(token))

    override suspend fun setTraits(traits: Map<String, String>) = PingFront.setTraits(traits)

    override suspend fun setEntitlement(entitlement: EntitlementMessage) = PingFront.setEntitlement(Mapping.entitlement(entitlement))

    override suspend fun setOffers(offers: List<OfferSlotMessage>) = PingFront.setOffers(offers.map(Mapping::slot))

    override suspend fun logout() = PingFront.logout()

    override suspend fun eraseMyData() = bridged { PingFront.eraseMyData() }

    override suspend fun exportMyData(): String = bridged { PingFront.exportMyData() }

    override suspend fun prepare() = bridged { PingFront.prepare() }

    // Chat

    override suspend fun openChat(topic: TopicMessage?) = PingFront.openChat(topic?.let(Mapping::topic))

    /** Closes the presented chat and returns once it is gone (at once when none is); an embedded chat is never waited for. */
    override suspend fun closeChat() = owned { PingFront.closeChatAndWait() }

    override suspend fun moment(name: String, props: Map<String, Any>): MomentResultMessage = owned {
        Mapping.momentResult(PingFront.moment(name, props.mapValues { (_, value) -> Mapping.momentValue(value) }))
    }

    // Push

    override suspend fun setPushToken(token: String?) = PingFront.setPushToken(token)

    override suspend fun handlePush(payload: Map<String, Any?>, opened: Boolean): Boolean {
        val data = Mapping.fcmData(payload)
        if (!PingFront.isPingFrontPush(data)) return false
        // A tap takes the SDK's own tap path: nothing opens for a person who logged out since (review AN-18).
        return if (opened) PingFront.openPush(data) else PingFront.handlePush(data)
    }

    override suspend fun isPingFrontPush(payload: Map<String, Any?>): Boolean = PingFront.isPingFrontPush(Mapping.fcmData(payload))

    // Reports

    override suspend fun openReport(prefill: String?) = PingFront.openReport(prefill)

    // Chat links: the SDK applies the rules (any string is safe; a non-link is false).

    override suspend fun handleUrl(url: String): Boolean = PingFront.handle(Uri.parse(url))

    override suspend fun reportBug(text: String, screenshot: ByteArray?) = bridged { PingFront.reportBug(text, screenshot) }

    // Self-check

    override suspend fun selfCheck(): SelfCheckMessage = owned {
        val result = PingFront.selfCheck()
        SelfCheckMessage(passed = result.passed, code = if (result.passed) null else result.code ?: "unexpected", line = result.line)
    }

    // Language, store, push permission

    override suspend fun setLanguage(tag: String?) {
        PingFront.language = tag
    }

    override suspend fun language(): String? = PingFront.language

    override suspend fun storeAccountToken(): String? = owned { PingFront.storeAccountToken() }

    override suspend fun usesAppBadge(): Boolean = PingFront.usesAppBadge

    override suspend fun setChatViewPadding(viewId: Long, left: Double, top: Double, right: Double, bottom: Double) {
        chatViews?.setPadding(viewId.toInt(), left, top, right, bottom)
    }

    /**
     * Android 13+: the `POST_NOTIFICATIONS` runtime permission. Earlier versions need no prompt. Calls made while the
     * prompt is up share it (its result key is fixed): every caller gets the one answer.
     */
    override suspend fun requestPushAuthorization(): Boolean = owned {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return@owned NotificationManagerCompat.from(context).areNotificationsEnabled()
        val permission = Manifest.permission.POST_NOTIFICATIONS
        if (ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED) return@owned true
        notificationPrompt.await {
            val answer = CompletableDeferred<Boolean>()
            val launcher = results.activityResultRegistry.register(Names.NOTIFICATIONS_REQUEST, ActivityResultContracts.RequestPermission()) {
                answer.complete(it)
            }
            try {
                launcher.launch(permission)
                answer.await()
            } finally {
                launcher.unregister()
            }
        }
    }

    private val notificationPrompt = SharedRequest<Boolean>(scope)

    /** Silent pushes are the push module's on Android (`PingFrontMessagingService`). */
    override suspend fun handleBackgroundPush(payload: Map<String, Any?>): String? = null

    // Look and team actions

    override suspend fun look(): LookMessage = Snapshots.look(PingFront.look.value)

    override suspend fun completeTeamAction(id: String) {
        (teamActions.take(id) ?: throw noTeamAction()).complete()
    }

    override suspend fun failTeamAction(id: String, message: String) {
        (teamActions.take(id) ?: throw noTeamAction()).fail(message)
    }

    private fun noTeamAction() = BridgeError("invalid_input", "No team action with this id is waiting; it was answered already.", null)

    // Conversation

    private val conversation get() = PingFront.conversation

    override suspend fun conversationState(): ConversationMessage =
        Snapshots.conversation(conversation.state.value, conversation.draft.value, conversation.composerInsertion.value)

    override suspend fun conversationSend(text: String, photos: List<ByteArray>) = conversation.send(text, photos)

    private fun pending(clientId: String): PendingMessage =
        conversation.state.value.pending.firstOrNull { it.clientId == clientId } ?: throw Snapshots.notFound("pending message")

    override suspend fun conversationRetry(clientId: String) = conversation.retry(pending(clientId))

    override suspend fun conversationDiscard(clientId: String) = conversation.discard(pending(clientId))

    override suspend fun conversationLoadOlder() = conversation.loadOlder()

    override suspend fun conversationChoose(messageId: String, cardId: String, optionId: String) {
        val (message, card) = Snapshots.card(conversation.state.value, messageId, cardId) ?: throw Snapshots.notFound("choices card")
        val choices = card as? Card.Choices ?: throw Snapshots.notFound("choices card")
        val option = choices.options.firstOrNull { it.id == optionId } ?: throw Snapshots.notFound("choice")
        conversation.choose(option, choices, message)
    }

    override suspend fun conversationRate(messageId: String, cardId: String, rating: Long) {
        val (message, card) = Snapshots.card(conversation.state.value, messageId, cardId) ?: throw Snapshots.notFound("rating card")
        val ratingCard = card as? Card.Rating ?: throw Snapshots.notFound("rating card")
        conversation.rate(rating.coerceIn(Int.MIN_VALUE.toLong(), Int.MAX_VALUE.toLong()).toInt(), ratingCard, message)
    }

    override suspend fun conversationOpenCard(messageId: String, cardId: String) {
        val (message, card) = Snapshots.card(conversation.state.value, messageId, cardId) ?: throw Snapshots.notFound("card")
        conversation.open(card, message)
    }

    override suspend fun conversationSetTyping(typing: Boolean) = conversation.setTyping(typing)

    override suspend fun conversationReload() = conversation.reload()

    override suspend fun conversationMarkRead() = conversation.markRead()

    override suspend fun conversationSetDraft(text: String) = conversation.updateDraft(text)

    override suspend fun conversationConsumeInsertion() = conversation.consumeInsertion()

    override suspend fun conversationPhotoData(clientId: String, sha256: String): ByteArray? {
        val photo = pending(clientId).photos.firstOrNull { it.sha256 == sha256 } ?: return null
        return owned { conversation.photoData(photo) }
    }

    override suspend fun conversationRefreshedImageUrl(messageId: String, attachmentId: String): String? {
        val message = conversation.state.value.messages.firstOrNull { it.id == messageId } ?: throw Snapshots.notFound("message")
        val image = message.parts.filterIsInstance<MessagePart.Image>().firstOrNull { it.attachmentId == attachmentId }
            ?: throw Snapshots.notFound("image")
        return owned { conversation.refreshedUrl(image) }
    }

    override suspend fun conversationCooldownRemaining(scope: String): Long? =
        conversation.cooldownRemaining(RateScope(scope))?.inWholeMilliseconds

    // Callbacks from the chat

    private fun apply(handlesOffers: Boolean, closesChatForOffers: Boolean, handlesLinks: Boolean) {
        offers.closesChat = closesChatForOffers
        // Unset when Dart has no handler, so a store module (Billing) handles offers instead.
        PingFront.onOffer = if (handlesOffers) offers::forward else null
        PingFront.onLink = if (handlesLinks) links::forward else null
    }

    private suspend fun <T> bridged(body: suspend () -> T): T = owned {
        try {
            body()
        } catch (e: PingFrontException) {
            throw Mapping.bridgeError(e)
        }
    }

    /** Runs a call inside [scope], so it ends when the engine detaches instead of in Pigeon's own coroutine. */
    private suspend fun <T> owned(body: suspend () -> T): T = kotlinx.coroutines.withContext(scope.coroutineContext) { body() }
}

