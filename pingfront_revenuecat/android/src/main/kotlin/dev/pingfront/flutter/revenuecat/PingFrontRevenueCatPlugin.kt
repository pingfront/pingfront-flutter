package dev.pingfront.flutter.revenuecat

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
 * [RevenueCatAdapterFactory] for the module when Dart configures with `PingFrontRevenueCat.module()`.
 */
public class PingFrontRevenueCatPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit
}
