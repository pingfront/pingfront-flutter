import Flutter
import Observation
import PingFront

/// Forwards `PingFront.shared.events` while Dart listens. The SDK hands every listener its own
/// stream, so a Dart listen starts one loop and a cancel ends it.
final class EventStream: EventsStreamHandler {
    private var task: Task<Void, Never>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<EventMessage>) {
        task?.cancel()
        task = Task { @MainActor in
            for await event in PingFront.shared.events {
                if Task.isCancelled { return }
                sink.success(Mapping.event(event))
            }
        }
    }

    override func onCancel(withArguments arguments: Any?) {
        task?.cancel()
        task = nil
    }
}

/// Sends the unread count (an `@Observable` property) to Dart: the current value, then changes.
final class UnreadStream: UnreadCountsStreamHandler {
    private var observer: UnreadObserver?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<Int64>) {
        let observer = UnreadObserver { sink.success(Int64($0)) }
        self.observer = observer
        Task { @MainActor in observer.start() }
    }

    override func onCancel(withArguments arguments: Any?) {
        let observer = self.observer
        self.observer = nil
        Task { @MainActor in observer?.stop() }
    }
}

/// Not isolated, so the stream handler (called outside any actor) can create it; its work runs on
/// the main actor.
final class UnreadObserver {
    private let emit: (Int) -> Void
    private var active = false
    private var last: Int?

    init(emit: @escaping (Int) -> Void) { self.emit = emit }
}

@MainActor
extension UnreadObserver {
    func start() {
        active = true
        send()
    }

    func stop() { active = false }

    private func send() {
        guard active else { return }
        let count = withObservationTracking {
            PingFront.shared.unreadCount
        } onChange: { [weak self] in
            Task { @MainActor in self?.send() }
        }
        if count != last {
            last = count
            emit(count)
        }
    }
}

/// Keeps the team actions Dart received until Dart answers them.
final class TeamActionRegistry {
    private var waiting: [String: TeamAction] = [:]
}

@MainActor
extension TeamActionRegistry {
    func keep(_ action: TeamAction) { waiting[action.id] = action }

    func take(_ id: String) -> TeamAction? { waiting.removeValue(forKey: id) }
}

/// Forwards `PingFront.shared.teamActions` while Dart listens. Actions not answered yet are replayed to each
/// new stream, so a Dart listen after a hot restart still sees them.
final class TeamActionStream: TeamActionsStreamHandler {
    private let registry: TeamActionRegistry
    private var task: Task<Void, Never>?

    init(registry: TeamActionRegistry) { self.registry = registry }

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<TeamActionMessage>) {
        task?.cancel()
        let registry = registry
        task = Task { @MainActor in
            for await action in PingFront.shared.teamActions {
                if Task.isCancelled { return }
                registry.keep(action)
                sink.success(Mapping.teamAction(action))
            }
        }
    }

    override func onCancel(withArguments arguments: Any?) {
        task?.cancel()
        task = nil
    }
}

/// Sends an `@Observable` value to Dart: the current value, then one value per change (changes made in the same
/// main-actor turn arrive as one).
final class ObservedValue<Value> {
    private let read: @MainActor () -> Value
    private let emit: (Value) -> Void
    private var active = false

    init(read: @escaping @MainActor () -> Value, emit: @escaping (Value) -> Void) {
        self.read = read
        self.emit = emit
    }
}

@MainActor
extension ObservedValue {
    func start() {
        active = true
        send()
    }

    func stop() { active = false }

    private func send() {
        guard active else { return }
        let value = withObservationTracking { read() } onChange: { [weak self] in
            Task { @MainActor in self?.send() }
        }
        emit(value)
    }
}

/// The conversation snapshot while Dart listens.
final class ConversationStream: ConversationStatesStreamHandler {
    private var observer: ObservedValue<ConversationMessage>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<ConversationMessage>) {
        let observer = ObservedValue(read: { Mapping.conversation(PingFront.shared.conversation) }, emit: { sink.success($0) })
        self.observer?.deactivate()
        self.observer = observer
        Task { @MainActor in observer.start() }
    }

    override func onCancel(withArguments arguments: Any?) {
        observer?.deactivate()
        observer = nil
    }
}

/// The resolved look while Dart listens.
final class LookStream: LooksStreamHandler {
    private var observer: ObservedValue<LookMessage>?

    override func onListen(withArguments arguments: Any?, sink: PigeonEventSink<LookMessage>) {
        let observer = ObservedValue(read: { Mapping.look(PingFront.shared.look) }, emit: { sink.success($0) })
        self.observer?.deactivate()
        self.observer = observer
        Task { @MainActor in observer.start() }
    }

    override func onCancel(withArguments arguments: Any?) {
        observer?.deactivate()
        observer = nil
    }
}

extension ObservedValue {
    /// Stops from any context; the observer's work runs on the main actor.
    func deactivate() { Task { @MainActor in self.stop() } }
}
