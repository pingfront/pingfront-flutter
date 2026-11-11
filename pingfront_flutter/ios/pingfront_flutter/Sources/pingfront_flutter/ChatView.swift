import Flutter
import PingFront
import SwiftUI
import UIKit

/// Creates the embedded chat: the SDK's SwiftUI `PingFrontChatView` in a hosting controller.
///
/// Once the view is in a window, the hosting controller becomes a child of the nearest view controller (the
/// Flutter view controller), so the chat gets the safe area, the keyboard, trait changes and presentations
/// (photo picker, Safari, the report sheet) like any UIKit child. The chat marks itself visible while it is in a
/// window: Flutter takes a platform view out of the window when it leaves the screen (another tab) and releases
/// it when the widget is disposed.
///
/// Flutter calls the factory on the main thread; the `@preconcurrency` conformances let the compiler check that at
/// run time instead of trusting it.
final class ChatViewFactory: NSObject, @preconcurrency FlutterPlatformViewFactory {
    private let api: PingFrontFlutterApi

    /// Flutter registers plugins outside any actor; the factory only keeps the Dart API for first-frame reports.
    init(api: PingFrontFlutterApi) {
        self.api = api
        super.init()
    }

    @MainActor
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> any FlutterPlatformView {
        let api = api
        return ChatPlatformView(topic: Mapping.topic(creationParams: args)) {
            // Dart takes the placeholder away. A failure means Dart is gone (hot restart).
            Task { @MainActor in try? await api.onChatViewShown(viewId: viewId) }
        }
    }

    func createArgsCodec() -> any FlutterMessageCodec & NSObjectProtocol { FlutterStandardMessageCodec.sharedInstance() }
}

/// One embedded chat.
@MainActor
final class ChatPlatformView: NSObject, @preconcurrency FlutterPlatformView {
    private let container: ChatContainerView

    init(topic: ChatTopic?, onShown: @escaping @MainActor () -> Void) {
        container = ChatContainerView(host: UIHostingController(rootView: PingFrontChatView(topic: topic)), onShown: onShown)
        super.init()
    }

    func view() -> UIView { container }

    /// Flutter releases the platform view when the widget is disposed: the hosting controller leaves its parent.
    deinit {
        let container = container
        Task { @MainActor in container.release() }
    }
}

/// Holds the hosting controller's view and makes the controller a child of the view controller it lands in.
final class ChatContainerView: UIView {
    private let host: UIHostingController<PingFrontChatView>
    private var onShown: (@MainActor () -> Void)?

    init(host: UIHostingController<PingFrontChatView>, onShown: @escaping @MainActor () -> Void) {
        self.host = host
        self.onShown = onShown
        super.init(frame: .zero)
        host.view.backgroundColor = .clear
        host.view.frame = bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(host.view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// The first layout in a window with a real size: SwiftUI renders in this pass, so the report follows it.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard window != nil, bounds.width > 0, bounds.height > 0, let report = onShown else { return }
        onShown = nil
        Task { @MainActor in report() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, host.parent == nil, let parent = nearestViewController() else { return }
        parent.addChild(host)
        host.didMove(toParent: parent)
    }

    func release() {
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = superview
        while let next = responder {
            if let controller = next as? UIViewController { return controller }
            responder = next.next
        }
        return nil
    }
}
