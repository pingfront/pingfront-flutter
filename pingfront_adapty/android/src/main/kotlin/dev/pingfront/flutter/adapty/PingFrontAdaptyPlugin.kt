package dev.pingfront.flutter.adapty

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Registers nothing: the plugin exists so Flutter links the native adapter. `pingfront_flutter` asks
 * [AdaptyAdapterFactory] for the module when Dart configures with `PingFrontAdapty.module()`.
 */
public class PingFrontAdaptyPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding): Unit = Unit
}
