package dev.pingfront.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.view.View
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultRegistry
import androidx.activity.result.ActivityResultRegistryOwner
import androidx.activity.result.contract.ActivityResultContract
import androidx.activity.result.contract.ActivityResultContracts.RequestMultiplePermissions
import androidx.compose.ui.platform.ViewCompositionStrategy
import androidx.core.app.ActivityCompat
import androidx.core.app.ActivityOptionsCompat
import androidx.lifecycle.LifecycleOwner
import dev.pingfront.look.ChatTopic
import dev.pingfront.ui.PingFrontChatView
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Creates the embedded chat: the Android SDK's [PingFrontChatView], shown with hybrid composition so the composer gets
 * real IME input and accessibility. The view owns its composition and, in a window without lifecycle owners
 * (`FlutterActivity` is not a `ComponentActivity`), its own owners and recomposer. Only the activity result registry
 * comes from here there: `FlutterActivity` has none, so [ActivityResults] routes the photo picker, the camera and
 * permission prompts through the plugin binding.
 */
internal class ChatViewFactory(
    private val activity: () -> Activity?,
    private val results: ActivityResults,
    private val onShown: (Int) -> Unit,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableMapOf<Int, java.lang.ref.WeakReference<ChatPlatformView>>()

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val padding = ((args as? Map<*, *>)?.get("padding") as? List<*>).orEmpty().map { (it as? Number)?.toDouble() ?: 0.0 }
        return ChatPlatformView(context, topic(args), padding, activity(), results) { onShown(viewId) }.also {
            views.values.removeAll { ref -> ref.get() == null }
            views[viewId] = java.lang.ref.WeakReference(it)
        }
    }

    /** Applies the safe-area padding Flutter left for a view (see `PingFrontChatView`). */
    fun setPadding(viewId: Int, left: Double, top: Double, right: Double, bottom: Double) {
        views[viewId]?.get()?.setPadding(left, top, right, bottom)
    }

    private fun topic(args: Any?): ChatTopic? {
        val topic = (args as? Map<*, *>)?.get("topic") as? Map<*, *> ?: return null
        val id = topic["id"] as? String ?: return null
        return Mapping.topic(TopicMessage(id, topic["label"] as? String, topic["symbol"] as? String ?: "other", topic["prefill"] as? String))
    }
}

/**
 * One embedded chat. The composition lives until [dispose], also while Flutter takes the view out of the window off
 * screen.
 *
 * Its insets are exactly the safe-area padding Flutter's layout left for the view (`MediaQuery.paddingOf`):
 * Flutter keeps the view clear of the keyboard itself (the `Scaffold` or `Dialog` lays it out above it), so the
 * chat never pads for the IME ([PingFrontChatView.Insets.Padding]).
 */
internal class ChatPlatformView(
    context: Context,
    topic: ChatTopic?,
    initialPadding: List<Double>,
    activity: Activity?,
    results: ActivityResults,
    private val onShown: () -> Unit,
) : PlatformView {
    private val density = context.resources.displayMetrics.density
    private var shown = false
    private val view = PingFrontChatView(context).apply {
        this.topic = topic
        insets = padding(initialPadding.getOrElse(0) { 0.0 }, initialPadding.getOrElse(1) { 0.0 }, initialPadding.getOrElse(2) { 0.0 }, initialPadding.getOrElse(3) { 0.0 })
        if (activity !is ComponentActivity) activityResultRegistryOwner = results
        // Flutter takes the view out of the window off screen; the composition stays until the widget is disposed
        // (`FlutterActivity` and `FlutterFragmentActivity` are both lifecycle owners).
        (activity as? LifecycleOwner)?.let { setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnLifecycleDestroyed(it)) }
    }

    /** Reports the first frame the chat draws, so Flutter can take its placeholder away. */
    private val firstDraw = object : android.view.ViewTreeObserver.OnDrawListener {
        override fun onDraw() {
            if (shown || view.height == 0) return
            shown = true
            // A listener can't be removed while it is being called; the report follows the drawn frame.
            view.post {
                view.viewTreeObserver.removeOnDrawListener(this)
                onShown()
            }
        }
    }

    init {
        view.viewTreeObserver.addOnDrawListener(firstDraw)
    }

    override fun getView(): View = view

    /** The safe-area padding Flutter left for this view (logical pixels are dp). */
    fun setPadding(left: Double, top: Double, right: Double, bottom: Double) {
        view.insets = padding(left, top, right, bottom)
    }

    private fun padding(left: Double, top: Double, right: Double, bottom: Double) = PingFrontChatView.Insets.Padding(
        px(left),
        px(top),
        px(right),
        px(bottom),
    )

    private fun px(dp: Double): Int = Math.round(dp * density).toInt()

    override fun dispose() {
        if (!shown) view.viewTreeObserver.removeOnDrawListener(firstDraw)
        view.disposeComposition()
    }
}

/**
 * An [ActivityResultRegistry] for activities that have none (`FlutterActivity`): launches go through the activity,
 * results and permission answers come back through the plugin binding's listeners.
 */
internal class ActivityResults :
    ActivityResultRegistryOwner,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {
    var activity: Activity? = null

    override val activityResultRegistry: ActivityResultRegistry = object : ActivityResultRegistry() {
        override fun <I, O> onLaunch(requestCode: Int, contract: ActivityResultContract<I, O>, input: I, options: ActivityOptionsCompat?) {
            val activity = activity ?: return run { dispatchResult(requestCode, Activity.RESULT_CANCELED, null) }
            contract.getSynchronousResult(activity, input)?.let {
                dispatchResult(requestCode, it.value)
                return
            }
            val intent = contract.createIntent(activity, input)
            if (intent.action == RequestMultiplePermissions.ACTION_REQUEST_PERMISSIONS) {
                val permissions = intent.getStringArrayExtra(RequestMultiplePermissions.EXTRA_PERMISSIONS).orEmpty()
                ActivityCompat.requestPermissions(activity, permissions, requestCode)
            } else {
                try {
                    activity.startActivityForResult(intent, requestCode, options?.toBundle())
                } catch (_: android.content.ActivityNotFoundException) {
                    dispatchResult(requestCode, Activity.RESULT_CANCELED, null)
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean =
        activityResultRegistry.dispatchResult(requestCode, resultCode, data)

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
        // The same intent ComponentActivity builds for its registry.
        val data = Intent()
            .putExtra(RequestMultiplePermissions.EXTRA_PERMISSIONS, permissions)
            .putExtra(RequestMultiplePermissions.EXTRA_PERMISSION_GRANT_RESULTS, grantResults)
        return activityResultRegistry.dispatchResult(requestCode, Activity.RESULT_OK, data)
    }
}
