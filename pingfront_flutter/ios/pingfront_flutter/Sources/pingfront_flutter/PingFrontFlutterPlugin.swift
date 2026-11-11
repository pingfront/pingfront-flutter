import Flutter
import UIKit

/// Registers the bridge between the Dart API and the native pingfront SDK.
///
/// The plugin wraps `PingFront.shared`; it keeps no state of its own besides which Dart callbacks
/// are set. Every host call runs on the main actor (the Pigeon methods are all async).
public final class PingFrontFlutterPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: any FlutterPluginRegistrar) {
        let messenger = registrar.messenger()
        let teamActions = TeamActionRegistry()
        let bridge = PingFrontBridge(messenger: messenger, teamActions: teamActions)
        PingFrontHostApiSetup.setUp(binaryMessenger: messenger, api: bridge)
        EventsStreamHandler.register(with: messenger, streamHandler: EventStream())
        UnreadCountsStreamHandler.register(with: messenger, streamHandler: UnreadStream())
        TeamActionsStreamHandler.register(with: messenger, streamHandler: TeamActionStream(registry: teamActions))
        ConversationStatesStreamHandler.register(with: messenger, streamHandler: ConversationStream())
        LooksStreamHandler.register(with: messenger, streamHandler: LookStream())
        registrar.register(ChatViewFactory(api: PingFrontFlutterApi(binaryMessenger: messenger)), withId: Names.chatViewType)
    }
}
