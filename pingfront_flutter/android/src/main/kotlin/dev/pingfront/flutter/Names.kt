package dev.pingfront.flutter

/**
 * The product name and every identifier derived from it on the Android side, in one place.
 * Dart keeps its copy in `lib/src/brand.dart`, Swift in `Names.swift`.
 */
internal object Names {
    /** The logcat tag, the same one the native SDK uses. */
    const val LOG_TAG = "PingFront"

    /** The activity result key of the notification permission request. */
    const val NOTIFICATIONS_REQUEST = "dev.pingfront.flutter.notifications"

    /** Optional modules shipped as separate artifacts, found at runtime so the plugin never forces them on an app. */
    const val PUSH_MODULE = "dev.pingfront.push.Push"
    const val BILLING_MODULE = "dev.pingfront.billing.Billing"

    /** The platform view type of the embedded chat (`PingFrontChatView` in Dart). */
    const val CHAT_VIEW_TYPE = "dev.pingfront/chat_view"

    /** Each vendor add-on's factory class, by adapter id (see [Adapters]). */
    val ADAPTER_FACTORIES: Map<String, String> = mapOf(
        "revenuecat" to "dev.pingfront.flutter.revenuecat.RevenueCatAdapterFactory",
        "superwall" to "dev.pingfront.flutter.superwall.SuperwallAdapterFactory",
        "adapty" to "dev.pingfront.flutter.adapty.AdaptyAdapterFactory",
    )

    /** The add-on package for each adapter id, for the message when it is missing. */
    val ADAPTER_PACKAGES: Map<String, String> = mapOf(
        "revenuecat" to "pingfront_revenuecat",
        "superwall" to "pingfront_superwall",
        "adapty" to "pingfront_adapty",
    )
}
