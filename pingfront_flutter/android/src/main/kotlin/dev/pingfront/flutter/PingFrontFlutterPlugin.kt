package dev.pingfront.flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import kotlinx.coroutines.launch

/**
 * Registers the bridge between the Dart API and the native pingfront SDK.
 *
 * The plugin wraps the `PingFront` object; it keeps no state of its own besides which Dart callbacks
 * are set. The native chat is its own activity (a full-height bottom sheet), so it shows over
 * `FlutterActivity` and `FlutterFragmentActivity` alike; `PingFrontChatView` embeds it as a platform view.
 * The SDK tracks activities from process start itself (its initializer), so the plugin reads no launch intent.
 */
class PingFrontFlutterPlugin : FlutterPlugin, ActivityAware {
    private var bridge: Bridge? = null
    private val results = ActivityResults()
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val teamActions = TeamActionRegistry()
        val flutterApi = PingFrontFlutterApi(binding.binaryMessenger)
        val bridge = Bridge(binding.applicationContext, flutterApi, teamActions, results)
        this.bridge = bridge
        val chatViews = ChatViewFactory({ activityBinding?.activity }, results) { viewId ->
            bridge.scope.launch {
                try {
                    flutterApi.onChatViewShown(viewId.toLong())
                } catch (_: BridgeError) {
                    // The Dart side is gone (hot restart).
                }
            }
        }
        bridge.chatViews = chatViews
        PingFrontHostApi.setUp(binding.binaryMessenger, bridge)
        EventsStreamHandler.register(binding.binaryMessenger, EventStream(bridge.scope))
        UnreadCountsStreamHandler.register(binding.binaryMessenger, UnreadStream(bridge.scope))
        TeamActionsStreamHandler.register(binding.binaryMessenger, TeamActionStream(bridge.scope, teamActions))
        ConversationStatesStreamHandler.register(binding.binaryMessenger, ConversationStream(bridge.scope))
        LooksStreamHandler.register(binding.binaryMessenger, LookStream(bridge.scope))
        binding.platformViewRegistry.registerViewFactory(Names.CHAT_VIEW_TYPE, chatViews)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        PingFrontHostApi.setUp(binding.binaryMessenger, null)
        bridge?.close()
        bridge = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        results.activity = binding.activity
        binding.addActivityResultListener(results)
        binding.addRequestPermissionsResultListener(results)
    }

    private fun detach() {
        activityBinding?.removeActivityResultListener(results)
        activityBinding?.removeRequestPermissionsResultListener(results)
        activityBinding = null
        results.activity = null
    }
}
