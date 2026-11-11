import Flutter
import Foundation
import PingFront

/// Mappings for the look, the conversation, team actions, log lines and vendor adapters.
extension Mapping {
    // MARK: Wire JSON

    /// The wire format: ISO-8601 dates with fractional seconds, as the server sends them.
    private static let wireEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.formatted(style))
        }
        return encoder
    }()

    /// JSON text of a wire value; `[]` when it cannot be encoded (never expected for SDK models).
    static func json(_ value: some Encodable) -> String {
        guard let data = try? wireEncoder.encode(value) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    static func ms(_ date: Date) -> Int64 { Int64((date.timeIntervalSince1970 * 1000).rounded()) }

    static func ms(_ duration: Duration) -> Int64 {
        let (seconds, attoseconds) = duration.components
        return seconds * 1000 + attoseconds / 1_000_000_000_000_000
    }

    // MARK: Logs

    static func logEntry(_ entry: PingFrontLogEntry) -> LogEntryMessage {
        let level: String =
            switch entry.level {
            case .off: "off"
            case .error: "error"
            case .debug: "debug"
            default: "info"
            }
        return LogEntryMessage(level: level, message: entry.message, category: entry.category)
    }

    static func pushEnvironment(_ name: String?) -> PushEnvironment? { name.flatMap(PushEnvironment.init(rawValue:)) }

    // MARK: Look

    static func colorMessage(_ c: PingFrontColor) -> ColorMessage { ColorMessage(light: c.light.hex, dark: c.dark.hex) }

    static func look(_ l: ResolvedLook) -> LookMessage {
        LookMessage(
            appName: l.appName,
            appIconUrl: l.appIconURL?.absoluteString,
            appIconPng: l.appIconPNG.map { FlutterStandardTypedData(bytes: $0) },
            accent: colorMessage(l.accent),
            onAccent: colorMessage(l.onAccent),
            background: colorMessage(l.background),
            teamBubble: colorMessage(l.teamBubble),
            text: colorMessage(l.text),
            muted: colorMessage(l.muted),
            scheme: l.scheme.rawValue,
            font: l.font.rawValue,
            corners: l.corners.rawValue,
            density: l.density.rawValue,
            headerStyle: l.headerStyle.rawValue,
            headerMemberId: l.headerMemberId,
            headerTitle: l.headerTitle?.values,
            showsLocalTime: l.showsLocalTime,
            showsReplyExpectation: l.showsReplyExpectation,
            welcomeTitle: l.welcomeTitle?.values,
            welcomeBody: l.welcomeBody?.values,
            showsWelcomeFaces: l.showsWelcomeFaces,
            topics: l.topics.map { LookTopicMessage(id: $0.id, label: $0.label?.values, symbol: $0.symbol.rawValue, prefill: $0.prefill?.values) },
            composerPlaceholder: l.composerPlaceholder?.values,
            allowsPhotos: l.allowsPhotos,
            allowsReports: l.allowsReports,
            showsNames: l.showsNames,
            showsAvatars: l.showsAvatars,
            timestamps: l.timestamps.rawValue,
            replyExpectation: l.replyExpectation?.values,
            aiName: l.aiName,
            teamJson: json(l.team),
            isDraft: l.isDraft,
            revision: Int64(l.revision),
            bubbleRadius: Int64(l.bubbleRadius.rounded())
        )
    }

    // MARK: Team actions

    static func teamAction(_ a: TeamAction) -> TeamActionMessage {
        TeamActionMessage(
            id: a.id, actionId: a.actionId, name: a.name, fields: a.fields, days: a.days.map(Int64.init),
            untilMs: a.until.map { ms($0) }, ackRequired: a.ackRequired, createdAtMs: ms(a.createdAt), expiresAtMs: ms(a.expiresAt))
    }

    // MARK: Conversation

    static func pending(_ p: PendingMessage) -> PendingMessageMessage {
        let state: String =
            switch p.state {
            case .queued: "queued"
            case .sending: "sending"
            case .failed: "failed"
            @unknown default: "unknown"
            }
        return PendingMessageMessage(
            clientId: p.clientId, text: p.text,
            photos: p.photos.map {
                PendingPhotoMessage(
                    width: Int64($0.width), height: Int64($0.height), bytes: Int64($0.bytes), sha256: $0.sha256, attachmentId: $0.attachmentId)
            },
            createdAtMs: ms(p.createdAt), attempts: Int64(p.attempts), state: state, failure: p.failure, heldFor: p.heldFor?.code)
    }

    static func timelineItem(_ item: TimelineItem) -> TimelineItemMessage {
        let (kind, id): (String, String) =
            switch item.content {
            case .message(let m): ("message", m.id)
            case .pending(let p): ("pending", p.clientId)
            @unknown default: ("unknown", item.id)
            }
        let side: String =
            switch item.side {
            case .team: "team"
            case .person: "person"
            case .system: "system"
            @unknown default: "unknown"
            }
        return TimelineItemMessage(
            id: item.id, contentKind: kind, contentId: id, side: side, startsGroup: item.startsGroup, endsGroup: item.endsGroup,
            startsPing: item.startsPing, isAi: item.isAI, authorName: item.authorName, dateMs: ms(item.date),
            startsTimeSection: item.startsTimeSection)
    }

    /// Reads every observable field of the conversation, so `withObservationTracking` sees each of them.
    static func conversation(_ c: Conversation) -> ConversationMessage {
        var phase = "unknown"
        var failureCode: String?
        switch c.phase {
        case .idle: phase = "idle"
        case .loading: phase = "loading"
        case .ready: phase = "ready"
        case .failed(let error):
            phase = "failed"
            failureCode = errorCode(error)
        @unknown default: break
        }
        var live = "unknown"
        var retryMs: Int64?
        var liveOffline = false
        switch c.live {
        case .stopped: live = "stopped"
        case .connecting: live = "connecting"
        case .live: live = "live"
        case .waiting(let retryIn, let offline):
            live = "waiting"
            retryMs = ms(retryIn)
            liveOffline = offline
        @unknown default: break
        }
        return ConversationMessage(
            phase: phase,
            failureCode: failureCode,
            messagesJson: json(c.messages),
            pending: c.pending.map(pending),
            timeline: c.timeline.map(timelineItem),
            hasOlder: c.hasOlder,
            isLoadingOlder: c.isLoadingOlder,
            teamJson: json(c.team),
            replyExpectation: c.replyExpectation,
            canSend: c.policy.canSend,
            closedReason: c.policy.reason?.rawValue,
            status: c.status.rawValue,
            typingIsAi: c.typing?.isAI,
            typingName: c.typing?.name,
            live: live,
            liveRetryInMs: retryMs,
            liveOffline: liveOffline,
            teamReadSeq: Int64(c.teamReadSeq),
            isOffline: c.isOffline,
            isServerUnreachable: c.isServerUnreachable,
            draft: c.draft,
            composerInsertion: c.composerInsertion,
            coolingDown: RateScope.known.filter { c.cooldownRemaining($0) != nil }.map(\.rawValue),
            awaitingApproval: c.awaitingApproval.sorted()
        )
    }

    /// A message and one of its cards, by id.
    static func card(_ c: Conversation, messageId: String, cardId: String) -> (Message, Card)? {
        guard let message = c.messages.first(where: { $0.id == messageId }) else { return nil }
        for part in message.parts {
            if case .card(let cardPart) = part, cardPart.card.id == cardId { return (message, cardPart.card) }
        }
        return nil
    }

    static func notFound(_ what: String) -> BridgeError {
        BridgeError(code: "invalid_input", message: "No \(what) with this id is in the conversation; it may have changed.", details: nil)
    }

    // MARK: Topics from creation parameters (the embedded chat)

    static func topic(creationParams args: Any?) -> ChatTopic? {
        guard let params = args as? [String: Any], let topic = params["topic"] as? [String: Any], let id = topic["id"] as? String else {
            return nil
        }
        return Mapping.topic(
            TopicMessage(id: id, label: topic["label"] as? String, symbol: topic["symbol"] as? String ?? "other", prefill: topic["prefill"] as? String))
    }
}
