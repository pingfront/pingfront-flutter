/// Hands an offer tap to Dart so the paywall is never hidden. The presented chat is a sheet over the Flutter view
/// controller, so a paywall Dart pushes as a route would sit under it: with `closesChat` on (the default), the
/// presented chat closes first and Dart is called once it is off screen. `closePresentedChat` returns at once when
/// no chat is presented (an embedded chat stays where it is). A second tap replaces a first one that is still waiting.
///
/// Not isolated, so the bridge can create it from `register(with:)`; it works on the main actor.
final class OfferForwarder<Request> {
    var closesChat = true
    private let closePresentedChat: @MainActor () async -> Void
    private let deliver: @MainActor (Request) async -> Void
    private var task: Task<Void, Never>?

    init(closePresentedChat: @escaping @MainActor () async -> Void, deliver: @escaping @MainActor (Request) async -> Void) {
        self.closePresentedChat = closePresentedChat
        self.deliver = deliver
    }
}

@MainActor
extension OfferForwarder {
    /// The task that delivers the latest tap (tests await it).
    @discardableResult
    func forward(_ request: Request) -> Task<Void, Never> {
        task?.cancel()
        let task = Task { @MainActor [closesChat, closePresentedChat, deliver] in
            if closesChat { await closePresentedChat() }
            if Task.isCancelled { return }
            await deliver(request)
        }
        self.task = task
        return task
    }
}
