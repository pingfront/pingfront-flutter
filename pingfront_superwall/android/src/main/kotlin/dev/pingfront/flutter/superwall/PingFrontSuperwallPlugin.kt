package dev.pingfront.flutter.superwall

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
 * [SuperwallAdapterFactory] for the module when Dart configures with `PingFrontSuperwall.module()`.
 */
public class PingFrontSuperwallPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit
}
