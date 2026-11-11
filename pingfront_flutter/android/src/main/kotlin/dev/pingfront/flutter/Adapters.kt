package dev.pingfront.flutter

import dev.pingfront.PingFrontModule

/**
 * Vendor adapters come from add-on packages (`pingfront_revenuecat`, `pingfront_superwall`, `pingfront_adapty`),
 * so an app links only the vendor it uses and this plugin has no vendor dependency. Each add-on ships a factory
 * class ([Names.ADAPTER_FACTORIES]) with a static `module(Map<String, Any?>): PingFrontModule` that builds the
 * native adapter from the options Dart sent. It is found at runtime, like the push and billing modules.
 */
internal object Adapters {
    fun module(id: String, options: Map<String, Any?>): PingFrontModule? {
        val className = Names.ADAPTER_FACTORIES[id] ?: run {
            android.util.Log.e(Names.LOG_TAG, "Unknown module $id; it was skipped.")
            return null
        }
        return try {
            Class.forName(className).getMethod("module", Map::class.java).invoke(null, options) as PingFrontModule
        } catch (e: java.lang.reflect.InvocationTargetException) {
            // The add-on is there but its factory failed: report its own exception, not the reflection wrapper.
            android.util.Log.e(Names.LOG_TAG, "The $id adapter could not be created; it was skipped.", e.targetException)
            null
        } catch (_: ReflectiveOperationException) {
            val pkg = Names.ADAPTER_PACKAGES[id] ?: id
            android.util.Log.e(Names.LOG_TAG, "The $id adapter needs the $pkg package in your pubspec; it was skipped.")
            null
        } catch (_: ClassCastException) {
            android.util.Log.e(Names.LOG_TAG, "The $id add-on returned no module; it was skipped.")
            null
        }
    }
}
