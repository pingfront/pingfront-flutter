import Flutter
import PingFront
import UIKit

/// The host API: every Dart call lands here, on the main actor, and goes straight to
/// `PingFront.shared`.
///
/// The class itself is not isolated, so `register(with:)` (which Flutter calls outside any actor)
/// can create it; every member that touches the SDK is in the `@MainActor` extension below.
final class PingFrontBridge: PingFrontHostApi {
    private let flutterApi: PingFrontFlutterApi
    private let offers: OfferForwarder<OfferRequest>
    private let teamActions: TeamActionRegistry

    init(messenger: any FlutterBinaryMessenger, teamActions: TeamActionRegistry) {
        let api = PingFrontFlutterApi(binaryMessenger: messenger)
        flutterApi = api
        self.teamActions = teamActions
        offers = OfferForwarder(
            // Only the presented chat closes for an offer, whenever it shows; an embedded chat stays and adds no wait.
            closePresentedChat: { await PingFront.shared.closeChat() },
            deliver: { request in try? await api.onOffer(request: Mapping.offerRequest(request)) }
        )
    }
}

@MainActor
extension PingFrontBridge {
    private var sdk: PingFront { PingFront.shared }

    // MARK: Setup

    func configure(request: ConfigureRequest) async throws {
        let appearance = Mapping.appearance(request.appearance)
        let topics = request.topics.map { $0.map(Mapping.topic) }
        let modules = request.modules.compactMap { message -> PingFrontModule? in
            if let module = Mapping.module(message) { return module }
            return Adapters.module(id: message.id, options: message.options ?? [:])
        }
        let logs: PingFrontLogHandler? = request.forwardsLogs ? Self.logForwarder(flutterApi) : nil
        let baseURL = try request.baseUrl.map { text in
            guard let url = URL(string: text), url.scheme != nil else {
                throw BridgeError(code: "invalid_input", message: "baseUrl is not a URL: \(text)", details: nil)
            }
            return url
        }
        PingFront.configure(request.appKey) { config in
            config.appearance = appearance
            if let topics { config.topics = topics }
            if let baseURL { config.baseURL = baseURL }
            config.logLevel = Mapping.logLevel(request.logLevel)
            config.presentsChatForMoments = request.presentsChatForMoments
            for module in modules { config.use(module) }
            config.language = request.language
            config.logHandler = logs
            if let environment = Mapping.pushEnvironment(request.pushEnvironment) { config.pushEnvironment = environment }
            // PF-Wrapper on every request: flutter/<this plugin's version>.
            config.wrapper = PingFrontWrapper(name: "flutter", version: request.wrapperVersion)
        }
        apply(handlesOffers: request.handlesOffers, closesChatForOffers: request.closesChatForOffers, handlesLinks: request.handlesLinks)
    }

    func setHandlers(handlesOffers: Bool, closesChatForOffers: Bool, handlesLinks: Bool) async throws {
        apply(handlesOffers: handlesOffers, closesChatForOffers: closesChatForOffers, handlesLinks: handlesLinks)
    }

    func state() async throws -> StateMessage {
        StateMessage(
            isConfigured: sdk.isConfigured,
            unreadCount: Int64(sdk.unreadCount),
            isChatVisible: sdk.isChatVisible,
            isTestDevice: sdk.isTestDevice,
            person: sdk.person.map(Mapping.person),
            configurationProblem: sdk.configurationProblem.map(Mapping.problem)
        )
    }

    // MARK: Identity

    func identify(userId: String, name: String?, email: String?) async throws {
        sdk.identify(userId: userId, name: name, email: email)
        PingFrontFlutterIdentity.currentUserId = userId
    }

    func identifyWithToken(token: String) async throws {
        sdk.identify(token: token)
        // The SDK identifies the person as the token's `sub`; a token it refuses leaves the person as they were.
        if let userId = Mapping.identityTokenSubject(token) { PingFrontFlutterIdentity.currentUserId = userId }
    }

    func setTraits(traits: [String: String]) async throws { sdk.setTraits(traits) }

    func setEntitlement(entitlement: EntitlementMessage) async throws {
        sdk.setEntitlement(Mapping.entitlement(entitlement))
    }

    func setOffers(offers: [OfferSlotMessage]) async throws { sdk.setOffers(offers.map(Mapping.slot)) }

    func logout() async throws {
        sdk.logout()
        PingFrontFlutterIdentity.currentUserId = nil
    }

    func eraseMyData() async throws {
        // Cleared before the erase, so an add-on reading it when the new guest's store account token arrives never
        // sees the erased id; put back when the erase fails, since the person is still signed in then.
        let userId = PingFrontFlutterIdentity.currentUserId
        PingFrontFlutterIdentity.currentUserId = nil
        do throws(PingFrontError) { try await sdk.eraseMyData() } catch {
            if PingFrontFlutterIdentity.currentUserId == nil { PingFrontFlutterIdentity.currentUserId = userId }
            throw Mapping.bridgeError(error)
        }
    }

    func exportMyData() async throws -> String {
        do throws(PingFrontError) {
            return String(decoding: try await sdk.exportMyData(), as: UTF8.self)
        } catch { throw Mapping.bridgeError(error) }
    }

    func prepare() async throws {
        do throws(PingFrontError) { try await sdk.prepare() } catch { throw Mapping.bridgeError(error) }
    }

    // MARK: Chat

    func openChat(topic: TopicMessage?) async throws { sdk.openChat(topic: topic.map(Mapping.topic)) }

    /// Returns once the SDK's sheet is gone; at once when only an embedded chat is on screen (the SDK never waits
    /// for an embedded chat).
    func closeChat() async throws { await sdk.closeChat() }

    func moment(name: String, props: [String: Any]) async throws -> MomentResultMessage {
        Mapping.momentResult(await sdk.moment(name, props: props.compactMapValues(Mapping.momentValue)))
    }

    // MARK: Push

    func setPushToken(token: String?) async throws {
        // The SDK takes the APNs token as Data; Dart passes it as hex. `nil` (or empty) clears it, so the
        // server stops sending pushes to this install.
        guard let token, !token.isEmpty else { return sdk.setPushToken(nil) }
        guard let data = Mapping.data(hex: token) else {
            throw BridgeError(code: "invalid_input", message: "The APNs token must be hex, as getAPNSToken() returns it.", details: nil)
        }
        sdk.setPushToken(data)
    }

    func handlePush(payload: [String: Any?], opened: Bool) async throws -> Bool {
        let userInfo = Mapping.userInfo(payload)
        guard sdk.isPingFrontPush(userInfo: userInfo) else { return false }
        if opened { return sdk.handlePush(userInfo: userInfo) }
        sdk.pushReceived(userInfo: userInfo)
        return true
    }

    func isPingFrontPush(payload: [String: Any?]) async throws -> Bool {
        sdk.isPingFrontPush(userInfo: Mapping.userInfo(payload))
    }

    // MARK: Reports

    func openReport(prefill: String?) async throws { sdk.openReport(prefill: prefill) }

    // MARK: Chat links

    /// A string that isn't a URL is not a chat link; the SDK applies the rest of the rules.
    func handleUrl(url: String) async throws -> Bool {
        guard let parsed = URL(string: url) else { return false }
        return sdk.handle(parsed)
    }

    func reportBug(text: String, screenshot: FlutterStandardTypedData?) async throws {
        do throws(PingFrontError) {
            try await sdk.reportBug(text: text, screenshot: screenshot?.data)
        } catch {
            throw Mapping.bridgeError(error)
        }
    }

    // MARK: Self-check

    func selfCheck() async throws -> SelfCheckMessage {
        let result = await sdk.selfCheck()
        return SelfCheckMessage(passed: result.passed, code: result.passed ? nil : (result.code ?? "unexpected"), line: result.line)
    }

    // MARK: Language, store, push permission

    func setLanguage(tag: String?) async throws { sdk.language = tag }

    func language() async throws -> String? { sdk.language }

    /// Lowercase, the UUID text form the native SDKs document (and React Native and Android return).
    func storeAccountToken() async throws -> String? { sdk.storeAccountToken?.uuidString.lowercased() }

    func usesAppBadge() async throws -> Bool { sdk.usesAppBadge }

    func requestPushAuthorization() async throws -> Bool { await sdk.requestPushAuthorization() }

    func handleBackgroundPush(payload: [String: Any?]) async throws -> String? {
        guard let result = await sdk.handleBackgroundPush(userInfo: Mapping.userInfo(payload)) else { return nil }
        switch result {
        case .newData: return "newData"
        case .failed: return "failed"
        default: return "noData"
        }
    }

    // MARK: Look and team actions

    func look() async throws -> LookMessage { Mapping.look(sdk.look) }

    func completeTeamAction(id: String) async throws {
        guard let action = teamActions.take(id) else { throw Self.noTeamAction }
        await action.complete()
    }

    func failTeamAction(id: String, message: String) async throws {
        guard let action = teamActions.take(id) else { throw Self.noTeamAction }
        await action.fail(message: message)
    }

    private static var noTeamAction: BridgeError {
        BridgeError(code: "invalid_input", message: "No team action with this id is waiting; it was answered already.", details: nil)
    }

    // MARK: Conversation

    private var conversation: Conversation { sdk.conversation }

    func conversationState() async throws -> ConversationMessage { Mapping.conversation(conversation) }

    func conversationSend(text: String, photos: [FlutterStandardTypedData]) async throws {
        conversation.send(text: text, photos: photos.map(\.data))
    }

    private func pendingMessage(_ clientId: String) throws -> PendingMessage {
        guard let message = conversation.pending.first(where: { $0.clientId == clientId }) else { throw Mapping.notFound("pending message") }
        return message
    }

    func conversationRetry(clientId: String) async throws { conversation.retry(try pendingMessage(clientId)) }

    func conversationDiscard(clientId: String) async throws { conversation.discard(try pendingMessage(clientId)) }

    func conversationLoadOlder() async throws { conversation.loadOlder() }

    func conversationChoose(messageId: String, cardId: String, optionId: String) async throws {
        guard let (message, card) = Mapping.card(conversation, messageId: messageId, cardId: cardId), case .choices(let choices) = card,
            let option = choices.options.first(where: { $0.id == optionId })
        else { throw Mapping.notFound("choices card") }
        conversation.choose(option, on: choices, in: message)
    }

    func conversationRate(messageId: String, cardId: String, rating: Int64) async throws {
        guard let (message, card) = Mapping.card(conversation, messageId: messageId, cardId: cardId), case .rating(let ratingCard) = card
        else { throw Mapping.notFound("rating card") }
        conversation.rate(Int(clamping: rating), on: ratingCard, in: message)
    }

    func conversationOpenCard(messageId: String, cardId: String) async throws {
        guard let (message, card) = Mapping.card(conversation, messageId: messageId, cardId: cardId) else { throw Mapping.notFound("card") }
        conversation.open(card, in: message)
    }

    func conversationSetTyping(typing: Bool) async throws { conversation.setTyping(typing) }

    func conversationReload() async throws { await conversation.reload() }

    func conversationMarkRead() async throws { conversation.markRead() }

    func conversationSetDraft(text: String) async throws { conversation.draft = text }

    func conversationConsumeInsertion() async throws { conversation.composerInsertion = nil }

    func conversationPhotoData(clientId: String, sha256: String) async throws -> FlutterStandardTypedData? {
        guard let photo = try pendingMessage(clientId).photos.first(where: { $0.sha256 == sha256 }) else { return nil }
        return await conversation.photoData(for: photo).map { FlutterStandardTypedData(bytes: $0) }
    }

    func conversationRefreshedImageUrl(messageId: String, attachmentId: String) async throws -> String? {
        guard let message = conversation.messages.first(where: { $0.id == messageId }) else { throw Mapping.notFound("message") }
        for part in message.parts {
            if case .image(let image) = part, image.attachmentId == attachmentId {
                return await conversation.refreshedURL(for: image)?.absoluteString
            }
        }
        throw Mapping.notFound("image")
    }

    func conversationCooldownRemaining(scope: String) async throws -> Int64? {
        conversation.cooldownRemaining(RateScope(rawValue: scope)).map { Mapping.ms($0) }
    }

    /// UIKit gives the hosted chat its safe area, keyboard included, from where the view sits in its window.
    func setChatViewPadding(viewId: Int64, left: Double, top: Double, right: Double, bottom: Double) async throws {}

    // MARK: Saved links (https://pingfront.sh/docs/offers#saved-links)

    func registerScreens(screens: [AppScreenMessage]) async throws {
        sdk.registerScreens(screens.map { AppScreen(id: $0.id, title: $0.title) })
    }

    /// The tap waits for Dart's answer. The SDK caps the wait at 10 seconds and cancels this handler then: an
    /// answer after that is ignored (it neither counts nor closes the chat). A timely `true` closes the presented
    /// chat, as a handled link does.
    func setScreenHandler(enabled: Bool) async throws {
        guard enabled else {
            sdk.onScreen = nil
            return
        }
        sdk.onScreen = { @MainActor [weak self] (screen: LinkScreen) async -> Bool in
            guard let self else { return false }
            // A Dart side that is gone (hot restart) answers false.
            let opened = (try? await self.flutterApi.onScreen(screen: LinkScreenMessage(id: screen.id, params: screen.params))) ?? false
            // Past the cap the SDK has already reported the tap as not handled.
            guard !Task.isCancelled else { return false }
            if opened { await self.sdk.closeChat() }
            return opened
        }
    }

    // MARK: Callbacks from the chat

    private func apply(handlesOffers: Bool, closesChatForOffers: Bool, handlesLinks: Bool) {
        offers.closesChat = closesChatForOffers
        // Unset when Dart has no handler, so a store module (`.storeKit`) handles offers instead.
        if handlesOffers {
            sdk.onOffer = { @MainActor [offers] (request: OfferRequest) in offers.forward(request) }
        } else {
            sdk.onOffer = nil
        }
        if handlesLinks {
            sdk.onLink = { @MainActor [weak self] (url: URL) async -> Bool in await self?.forward(url) ?? false }
        } else {
            sdk.onLink = nil
        }
    }

    /// The tap waits for Dart's answer. The SDK caps the wait at 10 seconds and cancels this handler then, opens a
    /// declined link the way the chat opens it (the plugin opens nothing itself; https://pingfront.sh/docs/chat-links), and
    /// replaces a message link still waiting when a newer one is tapped. An answer after the cap is ignored: it neither
    /// counts nor closes the chat. A timely `true` closes the presented chat.
    private func forward(_ url: URL) async -> Bool {
        // A Dart side that is gone (hot restart) answers false.
        let handled = (try? await flutterApi.onLink(url: url.absoluteString)) ?? false
        guard !Task.isCancelled else { return false }
        if handled { await sdk.closeChat() }
        return handled
    }

    /// Sends each SDK log line to Dart on the main actor. The SDK calls the handler from any thread.
    private static func logForwarder(_ api: PingFrontFlutterApi) -> PingFrontLogHandler {
        { entry in
            Task { @MainActor in
                // A failure means Dart is gone (hot restart); the line is in the system log anyway.
                try? await api.onLog(entry: Mapping.logEntry(entry))
            }
        }
    }
}
