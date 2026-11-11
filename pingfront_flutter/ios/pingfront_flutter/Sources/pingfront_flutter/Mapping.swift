import Foundation
import PingFront

/// Converts between the Pigeon transport shapes and the native SDK's types. Strings that name an
/// enum value travel as the Dart enum names; anything unknown maps to the SDK's fallback.
@MainActor
enum Mapping {
    // MARK: Dart to native

    static func color(_ message: ColorMessage?) -> PingFrontColor? {
        guard let message, let light = PingFrontColor(hex: message.light), let dark = PingFrontColor(hex: message.dark) else {
            return nil
        }
        return PingFrontColor(light: light.light, dark: dark.light)
    }

    static func appearance(_ m: AppearanceMessage) -> ChatAppearance {
        var a = ChatAppearance()
        a.accent = color(m.accent)
        a.background = color(m.background)
        a.teamBubble = color(m.teamBubble)
        a.scheme = m.scheme.flatMap(ChatLook.Scheme.init(rawValue:))
        a.font = m.font.flatMap(ChatLook.FontStyle.init(rawValue:))
        a.corners = m.corners.flatMap(ChatLook.Corners.init(rawValue:))
        a.density = m.density.flatMap(ChatLook.Density.init(rawValue:))
        a.timestamps = m.timestamps.flatMap(ChatLook.Timestamps.init(rawValue:))
        a.headerStyle = m.headerStyle.flatMap(ChatLook.HeaderStyle.init(rawValue:))
        a.headerTitle = m.headerTitle
        a.headerMemberId = m.headerMemberId
        a.replyExpectation = m.replyExpectation
        a.showsReplyExpectation = m.showsReplyExpectation
        a.showsLocalTime = m.showsLocalTime
        a.showsAvatars = m.showsAvatars
        a.showsNames = m.showsNames
        a.showsWelcomeFaces = m.showsWelcomeFaces
        a.welcomeTitle = m.welcomeTitle
        a.welcomeBody = m.welcomeBody
        a.composerPlaceholder = m.composerPlaceholder
        a.allowsPhotos = m.allowsPhotos
        a.allowsReports = m.allowsReports
        a.aiName = m.aiName
        return a
    }

    private static let presets: [String: ChatTopic] = Dictionary(
        uniqueKeysWithValues: [ChatTopic.billing, .bug, .idea, .question, .account, .feedback, .gift, .restore, .privacy].map {
            ($0.id, $0)
        })

    static func topic(_ m: TopicMessage) -> ChatTopic {
        // A preset without a custom label keeps the SDK's translated label, and takes the prefill given (as on Android).
        if m.label == nil, var preset = presets[m.id] {
            if let prefill = m.prefill { preset.prefill = LocalizedText(default: prefill) }
            return preset
        }
        let symbol = TopicSymbol(rawValue: m.symbol) ?? .other
        return ChatTopic(id: m.id, label: m.label ?? m.id, symbol: symbol, prefill: m.prefill)
    }

    static func module(_ m: ModuleMessage) -> PingFrontModule? {
        switch m.id {
        case "push": return .push
        case "store": return .storeKit(products: m.products ?? [])
        case "reports":
            var options: ReportOptions = []
            if m.shakeToReport ?? true { options.insert(.shakeToReport) }
            if m.logTail ?? true { options.insert(.logTail) }
            return .reports(options)
        default: return nil
        }
    }

    static func logLevel(_ name: String) -> PingFrontLogLevel {
        switch name {
        case "off": .off
        case "error": .error
        case "debug": .debug
        default: .info
        }
    }

    /// The `sub` claim of an identity token (an HS256 JWT), the user id the SDK identifies the person as; nil when the
    /// token isn't a JWT with a string `sub`, which the SDK refuses too. Only read, never verified (the server does).
    static func identityTokenSubject(_ token: String) -> String? {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }
        var base64 = segments[1].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
            let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = claims["sub"] as? String
        else { return nil }
        return sub
    }

    private static func date(_ ms: Int64?) -> Date? { ms.map { Date(timeIntervalSince1970: Double($0) / 1000) } }

    static func entitlement(_ m: EntitlementMessage) -> Entitlement {
        let state: Entitlement.State =
            switch m.state {
            case "none": .none
            case "trial": .trial
            case "active": .active
            case "grace": .grace
            case "billingRetry": .billingRetry
            case "cancelled": .cancelled
            case "expired": .expired
            case "lifetime": .lifetime
            default: .unknown
            }
        return Entitlement(
            state: state, productId: m.productId, renewsAt: date(m.renewsAtMs), expiresAt: date(m.expiresAtMs),
            gracePeriodEndsAt: date(m.gracePeriodEndsAtMs), source: m.source.map(Entitlement.Source.init(rawValue:)))
    }

    static func slot(_ m: OfferSlotMessage) -> OfferSlot {
        OfferSlot(
            id: m.id, title: m.title, kind: OfferSlot.Kind(rawValue: m.kind) ?? .standard, isAvailable: m.available,
            products: m.products.map { OfferSlot.Product(id: $0.id, price: $0.price, period: $0.period, trial: $0.trial) },
            source: m.source.flatMap(OfferSlot.Source.init(rawValue:)))
    }

    /// Dart numbers and booleans both arrive as `NSNumber`; only a real CFBoolean is a Bool.
    static func momentValue(_ value: Any) -> MomentValue? {
        switch value {
        case let text as String: return .string(text)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
            return .number(number.doubleValue)
        default: return nil
        }
    }

    static func userInfo(_ payload: [String: Any?]) -> [AnyHashable: Any] {
        var info: [AnyHashable: Any] = [:]
        for (key, value) in payload {
            if let value { info[key] = value }
        }
        return info
    }

    static func data(hex: String) -> Data? {
        let text = hex.trimmingCharacters(in: .whitespaces)
        guard text.count.isMultiple(of: 2), !text.isEmpty else { return nil }
        var data = Data(capacity: text.count / 2)
        var index = text.startIndex
        while index < text.endIndex {
            let next = text.index(index, offsetBy: 2)
            guard let byte = UInt8(text[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        return data
    }

    // MARK: Native to Dart

    static func person(_ p: PersonSummary) -> PersonMessage {
        PersonMessage(id: p.id, level: p.level.rawValue, name: p.name)
    }

    static func problemKind(_ kind: ConfigurationProblem.Kind) -> String {
        switch kind {
        case .invalidKey: "invalidKey"
        case .missingKey: "missingKey"
        case .unknownKey: "unknownKey"
        case .appPaused: "appPaused"
        case .option: "option"
        case .keychain: "keychain"
        case .offerHandler: "offerHandler"
        @unknown default: "unknown"
        }
    }

    static func problem(_ p: ConfigurationProblem) -> ProblemMessage {
        ProblemMessage(kind: problemKind(p.kind), message: p.message, disablesSdk: p.disablesSDK)
    }

    static func storeOffer(_ o: StoreOffer) -> StoreOfferMessage {
        StoreOfferMessage(kind: o.kind.rawValue, id: o.id, productId: o.productId)
    }

    static func slotMessage(_ s: OfferSlot) -> OfferSlotMessage {
        OfferSlotMessage(
            id: s.id, title: s.title, kind: s.kind.rawValue, available: s.isAvailable,
            products: s.products.map { OfferProductMessage(id: $0.id, price: $0.price, period: $0.period, trial: $0.trial) },
            source: s.source?.rawValue)
    }

    static func offerRequest(_ r: OfferRequest) -> OfferRequestMessage {
        OfferRequestMessage(
            offerId: r.offerId, cardId: r.cardId, messageId: r.messageId, slot: r.slot.map(slotMessage),
            storeOffer: r.storeOffer.map(storeOffer))
    }

    /// The same request as a plain map, for event data.
    static func requestData(_ r: OfferRequest) -> [String: Any?] {
        var data: [String: Any?] = ["offerId": r.offerId, "cardId": r.cardId, "messageId": r.messageId]
        if let offer = r.storeOffer {
            data["storeOffer"] = ["kind": offer.kind.rawValue, "id": offer.id, "productId": offer.productId] as [String: Any?]
        }
        return data
    }

    static func momentResult(_ result: MomentResult) -> MomentResultMessage {
        switch result {
        case .delivered: MomentResultMessage(kind: "delivered")
        case .heldOut: MomentResultMessage(kind: "heldOut")
        case .ignored: MomentResultMessage(kind: "ignored")
        case .invalidName: MomentResultMessage(kind: "invalidName")
        case .notListened: MomentResultMessage(kind: "notListened")
        case .scheduled: MomentResultMessage(kind: "scheduled")
        case .openRequested(let presented): MomentResultMessage(kind: "openRequested", presented: presented)
        case .failed(let error):
            MomentResultMessage(kind: "failed", errorCode: errorCode(error), errorMessage: error.errorDescription)
        @unknown default: MomentResultMessage(kind: caseName(result))
        }
    }

    static func errorCode(_ error: PingFrontError) -> String {
        switch error {
        case .server(let server): server.code.rawValue
        case .network: "network"
        case .notConfigured: "not_configured"
        case .coolingDown: "cooling_down"
        case .invalidInput: "invalid_input"
        case .invalidKey: "invalid_key"
        case .invalidResponse: "invalid_response"
        case .protectedDataUnavailable: "storage_unavailable"
        case .cancelled: "cancelled"
        @unknown default: "unexpected"
        }
    }

    static func bridgeError(_ error: PingFrontError) -> BridgeError {
        BridgeError(code: errorCode(error), message: error.errorDescription ?? errorCode(error), details: nil)
    }

    static func offerOutcome(_ outcome: OfferOutcome) -> (String, String?) {
        switch outcome {
        case .purchased: ("purchased", nil)
        case .pending: ("pending", nil)
        case .cancelled: ("cancelled", nil)
        case .unavailable: ("unavailable", nil)
        case .failed(let error):
            switch error {
            case .network: ("failed", "network")
            case .notAllowed: ("failed", "not_allowed")
            case .notVerified: ("failed", "not_verified")
            case .productNotFound: ("failed", "product_not_found")
            case .store: ("failed", "store_error")
            @unknown default: ("failed", caseName(error))
            }
        @unknown default: (caseName(outcome), nil)
        }
    }

    static func event(_ event: PingFrontEvent) -> EventMessage {
        switch event {
        case .chatOpened: return EventMessage(type: "chatOpened", data: [:])
        case .chatClosed: return EventMessage(type: "chatClosed", data: [:])
        case .reportSent: return EventMessage(type: "reportSent", data: [:])
        case .sessionRevoked: return EventMessage(type: "sessionRevoked", data: [:])
        case .unreadChanged(let count): return EventMessage(type: "unreadChanged", data: ["count": count])
        case .messageReceived(let m):
            return EventMessage(
                type: "messageReceived",
                data: ["id": m.id, "authorName": m.authorName, "preview": m.preview, "isPing": m.isPing, "isAi": m.isAI])
        case .sessionStarted(let p):
            return EventMessage(type: "sessionStarted", data: ["personId": p.id, "level": p.level.rawValue, "name": p.name])
        case .identityProblem(let problem):
            return EventMessage(type: "identityProblem", data: ["problem": problem.rawValue])
        case .offerRequested(let request):
            return EventMessage(type: "offerRequested", data: ["request": requestData(request)])
        case .offerCompleted(let request, let outcome):
            let (name, failure) = offerOutcome(outcome)
            return EventMessage(type: "offerCompleted", data: ["request": requestData(request), "outcome": name, "failure": failure])
        case .lookChanged(let revision, let draft):
            return EventMessage(type: "lookChanged", data: ["revision": revision, "draft": draft])
        case .configurationProblem(let p):
            return EventMessage(
                type: "configurationProblem", data: ["kind": problemKind(p.kind), "message": p.message, "disablesSdk": p.disablesSDK])
        case .messageSent(let m):
            return EventMessage(
                type: "messageSent",
                data: ["id": m.id, "textLength": m.textLength, "photoCount": m.photoCount, "repliesToPing": m.repliesToPing])
        case .cardOpened(let card):
            return EventMessage(
                type: "cardOpened", data: ["kind": card.kind.rawValue, "cardId": card.cardId, "messageId": card.messageId])
        @unknown default:
            // Passed through by name; Dart turns it into `PingFrontEvent.unknown`.
            return EventMessage(type: caseName(event), data: [:])
        }
    }

    /// The case name of an enum value, for values this plugin version does not know.
    static func caseName(_ value: Any) -> String {
        String(String(describing: value).prefix { $0 != "(" })
    }
}
