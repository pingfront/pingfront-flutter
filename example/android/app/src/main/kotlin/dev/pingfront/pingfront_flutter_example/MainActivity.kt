package dev.pingfront.pingfront_flutter_example

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * A `FlutterFragmentActivity` (a `ComponentActivity`), the recommended host for pingfront's embedded chat: the
 * window carries the owners and activity result registry the chat uses. `FlutterActivity` works too: the SDK's
 * `PingFrontChatView` then brings its own owners, and the plugin its result registry.
 */
class MainActivity : FlutterFragmentActivity()
