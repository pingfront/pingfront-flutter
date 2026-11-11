package dev.pingfront.flutter.superwall

import dev.pingfront.PingFrontModule
import dev.pingfront.model.OfferSlot
import dev.pingfront.superwall.Superwall
import dev.pingfront.superwall.SuperwallPlacement

/** Builds the native adapter from the options Dart sent; `pingfront_flutter` calls it by name. */
public object SuperwallAdapterFactory {
    /** Placements with their title and kind; products, params and the identity options are iOS only. */
    @JvmStatic
    public fun module(options: Map<String, Any?>): PingFrontModule {
        val placements = (options["placements"] as? List<*>).orEmpty().mapNotNull { raw ->
            val p = raw as? Map<*, *> ?: return@mapNotNull null
            val name = p["placement"] as? String ?: return@mapNotNull null
            val title = p["title"] as? String ?: return@mapNotNull null
            val kind = OfferSlot.Kind.entries.firstOrNull { it.name.equals(p["kind"] as? String, ignoreCase = true) } ?: OfferSlot.Kind.Standard
            SuperwallPlacement(name, title, kind)
        }
        return Superwall(*placements.toTypedArray())
    }
}
