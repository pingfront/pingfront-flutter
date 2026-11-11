import XCTest

@_spi(Fixtures) import PingFrontCore
@testable import pingfront_flutter

/// The offer rule on iOS: with closing on, Dart sees an offer tap only after the chat sheet is gone,
/// so a paywall pushed as a Flutter route is never under it.
@MainActor
final class OfferForwarderTests: XCTestCase {
    private var log: [String] = []
    private var presented = true
    private var waiting: [CheckedContinuation<Void, Never>] = []

    /// Closes every presented chat that is being waited for.
    private func hide() {
        waiting.forEach { $0.resume() }
        waiting = []
    }

    /// A presented chat that closes when `hide()` runs, or none (an embedded chat is never presented).
    private func makeForwarder() -> OfferForwarder<String> {
        OfferForwarder(
            closePresentedChat: { [unowned self] in
                guard self.presented else { return }
                self.log.append("close")
                await withCheckedContinuation { self.waiting.append($0) }
                self.log.append("hidden")
            },
            deliver: { [unowned self] request in self.log.append("deliver \(request)") }
        )
    }

    private func settle() async {
        for _ in 0..<5 { await Task.yield() }
    }

    func testClosesThePresentedChatAndWaitsBeforeDartSeesTheOffer() async {
        let forwarder = makeForwarder()
        let task = forwarder.forward("pro_yearly")
        await settle()
        XCTAssertEqual(log, ["close"], "Dart is not called while the chat is still on screen")
        hide()
        await task.value
        XCTAssertEqual(log, ["close", "hidden", "deliver pro_yearly"])
    }

    func testEmbeddedOnlyDeliversAtOnce() async {
        presented = false
        let start = ContinuousClock.now
        await makeForwarder().forward("pro_yearly").value
        XCTAssertEqual(log, ["deliver pro_yearly"])
        XCTAssertLessThan(ContinuousClock.now - start, .milliseconds(200), "no timeout was waited for")
    }

    func testASecondTapReplacesOneStillWaiting() async {
        let forwarder = makeForwarder()
        let first = forwarder.forward("first")
        await settle()
        let second = forwarder.forward("second")
        await settle()
        hide()
        await first.value
        await second.value
        XCTAssertFalse(log.contains("deliver first"), "the replaced tap is never delivered")
        XCTAssertEqual(log.last, "deliver second")
    }

    func testKeepsTheChatWhenDartOptedOut() async {
        let forwarder = makeForwarder()
        forwarder.closesChat = false
        await forwarder.forward("pro_yearly").value
        XCTAssertEqual(log, ["deliver pro_yearly"])
    }

}

/// Event, push-token and moment-value mappings.
@MainActor
final class MappingTests: XCTestCase {
    func testMapsEveryEventAndPassesUnknownOnesByName() {
        XCTAssertEqual(Mapping.event(.unreadChanged(3)).type, "unreadChanged")
        XCTAssertEqual(Mapping.event(.unreadChanged(3)).data["count"] as? Int, 3)
        XCTAssertEqual(Mapping.event(.chatClosed).type, "chatClosed")
        XCTAssertEqual(Mapping.caseName(Mapping.event(.reportSent).type), "reportSent")
    }

    func testHexPushTokens() {
        XCTAssertEqual(Mapping.data(hex: "00ff10"), Data([0x00, 0xFF, 0x10]))
        XCTAssertNil(Mapping.data(hex: "0g"))
        XCTAssertNil(Mapping.data(hex: "abc"))
    }

    func testMomentValuesKeepBooleansApart() {
        XCTAssertEqual(Mapping.momentValue(NSNumber(value: true)), .bool(true))
        XCTAssertEqual(Mapping.momentValue(NSNumber(value: 1)), .number(1))
        XCTAssertEqual(Mapping.momentValue("plans"), .string("plans"))
        XCTAssertNil(Mapping.momentValue([1, 2]))
    }
}

/// The mappings added for parity: the two new events, the look, the conversation (its messages as wire JSON,
/// checked against the protocol fixtures), log lines, and vendor add-ons that are not in the app.
@MainActor
final class ParityMappingTests: XCTestCase {
    func testMessageSentAndCardOpenedCarryTheirFields() {
        let sent = Mapping.event(.messageSent(SentMessage(id: "msg_1", textLength: 12, photoCount: 2, repliesToPing: true)))
        XCTAssertEqual(sent.type, "messageSent")
        XCTAssertEqual(sent.data["id"] as? String, "msg_1")
        XCTAssertEqual(sent.data["textLength"] as? Int, 12)
        XCTAssertEqual(sent.data["photoCount"] as? Int, 2)
        XCTAssertEqual(sent.data["repliesToPing"] as? Bool, true)
        let opened = Mapping.event(.cardOpened(OpenedCard(kind: CardKind(rawValue: "poll"), cardId: "c1", messageId: "msg_2")))
        XCTAssertEqual(opened.type, "cardOpened")
        XCTAssertEqual(opened.data["kind"] as? String, "poll", "a kind this plugin does not know keeps its wire name")
        XCTAssertEqual(opened.data["cardId"] as? String, "c1")
        XCTAssertEqual(opened.data["messageId"] as? String, "msg_2")
    }

    func testEveryFixtureMessageSurvivesTheTripToDart() throws {
        // The shared fixture sdk/Message.json, found from this file's folder (example/ios/RunnerTests).
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../pingfront_flutter/test/fixtures/sdk/Message.json").standardized
        let fixture = try JSONSerialization.jsonObject(with: Data(contentsOf: root)) as? [String: Any]
        let values = try XCTUnwrap(fixture?["valid"] as? [[String: Any]]).compactMap { $0["value"] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            return try (try? fractional.parse(text)) ?? Date.ISO8601FormatStyle().parse(text)
        }
        let messages = try decoder.decode([Message].self, from: JSONSerialization.data(withJSONObject: values))
        XCTAssertEqual(messages.count, 6)
        let json = Mapping.json(messages)
        XCTAssertEqual(try decoder.decode([Message].self, from: Data(json.utf8)), messages)
        XCTAssertTrue(json.contains("\"createdAt\":\"2026-10-30T18:00:00.000Z\""), json)
    }

    /// The test host is Clockwise itself, so the shared conversation and look hold whatever its earlier runs left;
    /// the mapping must carry them faithfully, whatever they are.
    func testTheConversationSnapshotMatchesTheConversation() throws {
        let conversation = PingFront.shared.conversation
        let m = Mapping.conversation(conversation)
        XCTAssertTrue(["idle", "loading", "ready", "failed"].contains(m.phase), m.phase)
        let messages = try JSONSerialization.jsonObject(with: Data(m.messagesJson.utf8)) as? [Any]
        XCTAssertEqual(messages?.count, conversation.messages.count)
        XCTAssertEqual(m.pending.map(\.clientId), conversation.pending.map(\.clientId))
        XCTAssertEqual(m.timeline.map(\.id), conversation.timeline.map(\.id))
        XCTAssertEqual(m.canSend, conversation.policy.canSend)
        XCTAssertEqual(m.draft, conversation.draft)
        XCTAssertTrue(["stopped", "connecting", "live", "waiting"].contains(m.live), m.live)
        XCTAssertNil(Mapping.card(conversation, messageId: "msg_not_there", cardId: "c1"))
    }

    func testTheLookTravelsAsDartNamesAndHex() throws {
        let look = PingFront.shared.look
        let m = Mapping.look(look)
        XCTAssertEqual(m.appName, look.appName)
        XCTAssertTrue(m.accent.light.hasPrefix("#") && m.accent.light.count == 7, m.accent.light)
        XCTAssertTrue(["auto", "light", "dark"].contains(m.scheme))
        XCTAssertTrue(["round", "soft", "square"].contains(m.corners))
        XCTAssertTrue([18, 12, 6].contains(m.bubbleRadius))
        XCTAssertEqual(m.topics.map(\.id), look.topics.map(\.id))
        let team = try JSONSerialization.jsonObject(with: Data(m.teamJson.utf8)) as? [Any]
        XCTAssertEqual(team?.count, look.team.count)
    }

    func testLogLinesKeepTheirLevelAndCategory() {
        let entry = Mapping.logEntry(PingFrontLogEntry(level: .debug, category: "network", message: "GET /v1/me 200"))
        XCTAssertEqual(entry.level, "debug")
        XCTAssertEqual(entry.category, "network")
        XCTAssertEqual(entry.message, "GET /v1/me 200")
    }

    func testAnAdapterWhoseAddOnIsMissingIsSkipped() {
        // Clockwise adds no vendor package: the lookup finds no class and the module is skipped, never a crash.
        XCTAssertNil(Adapters.module(id: "revenuecat", options: ["presentsPaywalls": true]))
        XCTAssertNil(Adapters.module(id: "a_vendor_from_the_future", options: [:]))
    }

    func testTheEmbeddedChatReadsItsTopicFromTheCreationParameters() {
        XCTAssertNil(Mapping.topic(creationParams: nil))
        XCTAssertNil(Mapping.topic(creationParams: ["topic": NSNull()]))
        let topic = Mapping.topic(creationParams: ["topic": ["id": "sync", "label": "Sync", "symbol": "bug", "prefill": "Sync stopped "]])
        XCTAssertEqual(topic?.id, "sync")
        XCTAssertEqual(topic?.symbol, .bug)
        XCTAssertEqual(Mapping.topic(creationParams: ["topic": ["id": "billing", "symbol": "billing"]]), .billing)
    }

    func testAPresetTopicKeepsItsLabelAndTakesThePrefill() {
        let topic = Mapping.topic(TopicMessage(id: "bug", symbol: "bug", prefill: "The alarm "))
        XCTAssertEqual(topic.id, "bug")
        XCTAssertNil(topic.label, "the SDK's translated label")
        XCTAssertEqual(topic.prefill, LocalizedText(default: "The alarm "))
        XCTAssertEqual(Mapping.topic(TopicMessage(id: "bug", symbol: "bug")), .bug)
    }

    func testAnEntitlementKeepsEveryDate() {
        let entitlement = Mapping.entitlement(
            EntitlementMessage(
                state: "grace", productId: "pro", renewsAtMs: 1_000, expiresAtMs: 2_000, gracePeriodEndsAtMs: 3_000,
                source: "app"))
        XCTAssertEqual(entitlement.state, .grace)
        XCTAssertEqual(entitlement.renewsAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(entitlement.expiresAt, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(entitlement.gracePeriodEndsAt, Date(timeIntervalSince1970: 3))
        XCTAssertNil(Mapping.entitlement(EntitlementMessage(state: "active")).expiresAt)
    }

    func testTheUserIdOfAnIdentityTokenIsItsSub() {
        func token(_ claims: String) -> String {
            let payload = Data(claims.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
            return "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"
        }
        XCTAssertEqual(Mapping.identityTokenSubject(token(#"{"sub":"user_42","iat":1}"#)), "user_42")
        XCTAssertNil(Mapping.identityTokenSubject(token(#"{"iat":1}"#)))
        XCTAssertNil(Mapping.identityTokenSubject(token(#"{"sub":42}"#)))
        XCTAssertNil(Mapping.identityTokenSubject("not a token"))
    }
}
