package dev.pingfront.flutter.revenuecat

import dev.pingfront.PingFrontModule
import dev.pingfront.revenuecat.RevenueCat

/** Builds the native adapter from the options Dart sent; `pingfront_flutter` calls it by name. */
public object RevenueCatAdapterFactory {
    /** The Android adapter has no options: it reports every offering and presents RevenueCat paywalls. */
    @JvmStatic
    public fun module(@Suppress("UNUSED_PARAMETER") options: Map<String, Any?>): PingFrontModule = RevenueCat
}
