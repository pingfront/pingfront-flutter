package dev.pingfront.flutter.adapty

import dev.pingfront.PingFrontModule
import dev.pingfront.adapty.Adapty

/** Builds the native adapter from the options Dart sent; `pingfront_flutter` calls it by name. */
public object AdaptyAdapterFactory {
    /** The placement ids; the identity, observer mode and paywall options are iOS only. */
    @JvmStatic
    public fun module(options: Map<String, Any?>): PingFrontModule {
        val placements = (options["placements"] as? List<*>).orEmpty().filterIsInstance<String>()
        return Adapty(*placements.toTypedArray())
    }
}
