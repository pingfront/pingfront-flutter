# pingfront for Flutter

In-app support chat and proactive messages for Flutter apps on iOS 17+ and Android 8.0+ (API 26). The plugin is
a thin bridge: the native [iOS SDK](https://github.com/pingfront/pingfront-ios#readme) and [Android SDK](https://github.com/pingfront/pingfront-android#readme) do the networking,
storage and chat, and the chat stays native. On iOS it is the Messages-style sheet, on Android the Google
Messages-style bottom sheet, presented over your Flutter view. Dart talks to them through
[Pigeon](https://pub.dev/packages/pigeon), so every call is typed end to end.

- [Layout](#layout)
- [Install](#install)
- [Quickstart](#quickstart)
- [API](#api)
- [Embedded chat](#embedded-chat)
- [Build your own chat UI](#build-your-own-chat-ui)
- [Language, logs, look and team actions](#language-logs-look-and-team-actions)
- [Vendor adapters](#vendor-adapters)
- [Offers and paywalls](#offers-and-paywalls)
- [Links](#links)
- [Links into the chat](#links-into-the-chat)
- [Push](#push)
- [Verify](#verify)
- [Parity notes](#parity-notes)
- [Run the example](#run-the-example)
- [Develop](#develop)

## Layout

| Path | What |
| --- | --- |
| `pingfront_flutter/` | The plugin package. Flutter's Swift Package Manager integration names a plugin after its folder, so the package lives in a folder with its own name. |
| `pingfront_flutter/lib` | The Dart API (`PingFront`), models, and the Pigeon bridge (`src/messages.g.dart`, generated). |
| `pingfront_flutter/pigeons/messages.dart` | The Dart-native contract. `tool/pigeon.sh` regenerates the Dart, Swift and Kotlin code. |
| `pingfront_flutter/ios/pingfront_flutter` | A Swift package that depends on the `PingFront` product of [pingfront-ios](https://github.com/pingfront/pingfront-ios). |
| `pingfront_flutter/android` | A Gradle library that depends on `sh.pingfront:pingfront`. |
| `pingfront_revenuecat/`, `pingfront_superwall/`, `pingfront_adapty/` | Add-on plugins for the vendor adapters, so an app links only the vendor it uses ([Vendor adapters](#vendor-adapters)). |
| `example/` | **Clockwise**, a small alarm app that integrates the plugin the way a customer would. |
| `screenshots/` | Captures from the example on the iOS Simulator and the Android emulator. |

The product name lives in one constants file per language: `lib/src/brand.dart`, `ios/.../Names.swift` and
`android/.../Names.kt`.

## Install

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
```

- **iOS:** the plugin is a Swift package, so Flutter's Swift Package Manager support must be on
  (`flutter config --enable-swift-package-manager`, or `config: enable-swift-package-manager: true` under
  `flutter:` in your pubspec). CocoaPods is not supported. Set the iOS deployment target to 17.0 in Xcode.
- **Android:** set `minSdk = 26` and `compileSdk = 36` (or later) in `android/app/build.gradle.kts`. Any Kotlin 2.2 or later
  works, and the plugin needs no Compose compiler (the embedded chat is the SDK's own `PingFrontChatView`). The native SDK comes
  from Maven Central (`sh.pingfront:pingfront`). For push or Play Billing, add `sh.pingfront:pingfront-push` or
  `sh.pingfront:pingfront-billing` to your app's dependencies; the plugin finds them at runtime.

## Quickstart

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PingFront.configure('pk_live_…');
  runApp(const MyApp());
}

// A Help row with the unread badge.
ValueListenableBuilder<int>(
  valueListenable: PingFront.unread,
  builder: (context, unread, _) => ListTile(
    title: const Text('Talk to us'),
    trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
    onTap: () => PingFront.openChat(topic: ChatTopic.billing),
  ),
);

// After sign-in and sign-out.
await PingFront.identify(userId: user.id, name: user.name, email: user.email);
await PingFront.logout();
```

`configure` sends nothing. The key is checked offline. A session starts on the first chat open, listened
moment, push open, bug report or `prepare()`.

Pass `null` instead of the key to have the native SDK read it from the app: `PingFrontAppKey` in `ios/Runner/Info.plist`
and a `pingfront.app_key` `<meta-data>` in `android/app/src/main/AndroidManifest.xml`, as the native SDKs read it.

Options:

```dart
await PingFront.configure(
  'pk_live_…',
  options: const PingFrontOptions(
    topics: [ChatTopic.billing, ChatTopic.bug, ChatTopic.idea],     // up to 6
    appearance: ChatAppearance(
      accent: PingFrontColor(Color(0xFF3550E6), Color(0xFF7D91FF)), // light, dark
      corners: ChatCorners.soft,
      headerStyle: ChatHeaderStyle.team,
      replyExpectation: 'Usually replies within a few hours',
    ),
    modules: [PingFrontModule.reports(), PingFrontModule.store(products: ['pro_yearly'])],
    logLevel: PingFrontLogLevel.debug,
    closesChatForOffers: true,             // the default, see below
    language: 'de',                        // your app's own language picker; null follows the system
    logHandler: (entry) => log('$entry'),  // native SDK lines, already redacted
    pushEnvironment: PushEnvironment.production, // iOS; null picks by build type
  ),
);
```

Flutter apps have no iOS AccentColor asset or Android theme color for the SDK to infer, so set `accent` in code
or in the dashboard. The dashboard look always wins over code.

## API

Everything is a static member of `PingFront`. Calls return futures that complete when the native SDK took the
call. Errors are `PingFrontException(code, message)`.

| Dart | iOS | Android |
| --- | --- | --- |
| `configure(appKey, options:)` (`appKey` may be `null`) | `PingFront.configure(_:_:)` | `PingFront.configure(context, key) {}` |
| `state()` | `isConfigured`, `unreadCount`, `isChatVisible`, `isTestDevice`, `person`, `configurationProblem` | the same `StateFlow`s |
| `identify(userId:, name:, email:)`, `identifyWithToken(token)` | `identify(userId:…)`, `identify(token:)` | `identify(…)`, `identify(IdentityToken)` |
| `setTraits`, `setEntitlement`, `setOffers` | the same | the same |
| `logout()`, `eraseMyData()`, `prepare()` | the same | the same |
| `exportMyData()` → `String` (JSON text) | `exportMyData()` (`Data`, decoded as UTF-8) | `exportMyData()` |
| `openChat(topic:)`, `closeChat()` | the same; `closeChat()` completes when the sheet is gone | the same; completes when the chat activity stopped |
| `moment(name, props)` → `MomentResult` | `moment(_:props:)` | `moment(name, props)` |
| `setPushToken(token)`, `handlePush(data, opened:)`, `isPingFrontPush(data)` | `setPushToken(_:)`, `handlePush` / `pushReceived` | `setPushToken`, `handlePush` |
| `openReport(prefill:)`, `reportBug(text, screenshot:)` | the same | the same |
| `handleUrl(url)` → `bool` | `handle(_:)` | `handle(uri)` |
| `unreadCount` (`Stream<int>`), `unread` (`ValueListenable<int>`) | observed `unreadCount` | `unreadCount` flow |
| `events` (`Stream<PingFrontEvent>`) | `events` | `events` |
| `onOffer`, `onLink` | `onOffer`, `onLink` | `onOffer`, `onLink` |
| `registerScreens(screens)`, `onScreen` | `registerScreens(_:)`, `onScreen` | `registerScreens`, `onScreen` |
| `selfCheck()` | see [Verify](#verify) | see [Verify](#verify) |
| `setLanguage(tag)`, `language()`, `PingFrontOptions.language` | `language` | `language` |
| `PingFrontOptions.logHandler` (`PingFrontLogEntry`) | `config.logHandler` | `logHandler` |
| `PingFrontChatView(topic:)` | `PingFrontChatView` | `PingFrontChatView` (the View; `PingFrontChat` in Compose) |
| `conversation` (`PingFrontConversation`) | `conversation` | `conversation` |
| `look()`, `looks` (`ResolvedLook`) | `look` | `look` |
| `teamActions` (`TeamAction.complete()`, `fail()`) | `teamActions` | `teamActions` |
| `storeAccountToken()` | `storeAccountToken` (UUID string, lowercased) | `storeAccountToken()` |
| `usesAppBadge()` | `usesAppBadge` | `usesAppBadge` |
| `requestPushAuthorization()` | `requestPushAuthorization()` | `POST_NOTIFICATIONS` request (Android 13+) |
| `handleBackgroundPush(data)` | `handleBackgroundPush(userInfo:)` | `null` (the push module handles it) |
| `PingFrontRevenueCat` / `PingFrontSuperwall` / `PingFrontAdapty` `.module()` | the `pingfront-ios-revenuecat` / `-superwall` / `-adapty` packages | `pingfront-revenuecat` / `-superwall` / `-adapty` |

`events` delivers `ChatOpened`, `ChatClosed`, `MessageReceived`, `MessageSent`, `CardOpened`, `UnreadChanged`, `SessionStarted`,
`SessionRevoked`, `IdentityProblemReported`, `OfferRequested`, `OfferCompleted`, `LookChanged`,
`ConfigurationProblemFound` and `ReportSent`. An event this plugin version does not know, or a malformed one,
arrives as `PingFrontEvent.unknown(type, data)` with the native name and fields, never as an error. Switch with a
default branch. `MomentResult` has `MomentUnknown` for the same reason, and unknown enum strings (levels,
problem kinds, offer kinds) decode to an `unknown` value or the native fallback. `CardOpened.card.kind` is a
`CardKind`, open like the wire: a kind this version does not know keeps its name (`isKnown` is false).

## Embedded chat

`PingFrontChatView` puts the native chat inside your layout: a tab, or a route of your own. It is the same chat
as `openChat` (SwiftUI `PingFrontChatView` on iOS, the Android SDK's View `PingFrontChatView` on Android), hosted as a platform
view.

```dart
Scaffold(
  appBar: AppBar(title: const Text('Help')),
  body: const PingFrontChatView(topic: ChatTopic.billing),
)
```

- **Visible only on screen.** The chat counts as visible (live updates, read receipts, no unread polling) while the
  view is on screen. Offstage, such as another tab an `IndexedStack` keeps alive or a route pushed over it, the
  widget drops the native view, so messages are not marked read behind the person's back. The thread and draft
  live in the SDK and come back with the view. Each chat on screen counts once for `isChatVisible`: a sheet that
  closes over an embedded chat leaves it true and sends no `ChatClosed`.
- **One chat.** While it is on screen, `openChat` focuses it instead of presenting a second chat over it: the
  composer takes the cursor and the topic's prefill. Chat links, notification taps and moments that open the chat
  do the same.
- **Keyboard.** Who keeps the chat clear of the keyboard depends on the platform:
  - **Android:** Flutter, as for any widget: the `Scaffold` around the chat with the default
    `resizeToAvoidBottomInset: true` ([docs](https://api.flutter.dev/flutter/material/Scaffold/resizeToAvoidBottomInset.html))
    or a `Dialog` lays the view out above the keyboard; the chat never pads for it. With `false` the keyboard covers
    the composer.
  - **iOS:** the chat itself, with SwiftUI's keyboard safe area (the part of the keyboard that overlaps the view).
    Give the `Scaffold` `resizeToAvoidBottomInset: false` on iOS: the composer then follows the keyboard also while
    the person drags it down. With `true` it still ends flush, but Flutter keeps the view's size until the keyboard
    is hidden, so a gap opens under the composer during an interactive dismissal: compare
    [with Flutter resizing](screenshots/ios-keyboard-dismiss-with-flutter-resize.png) and
    [with SwiftUI's keyboard safe area](screenshots/ios-keyboard-dismiss-with-swiftui.png). A `Dialog` works either
    way.

  ```dart
  Scaffold(
    resizeToAvoidBottomInset: defaultTargetPlatform != TargetPlatform.iOS,
    body: const PingFrontChatView(),
  )
  ```

  - **Android, during the animation:** while the native composer has focus, the platform view follows the IME late.
    As the keyboard opens it covers the composer for 4 to 6 frames; then the view tracks it one frame behind, in
    30 Hz steps, overlapping the composer by about 5 to 10 dp. As it closes, a blank band of up to about 115 dp shows
    under the composer for about 200 ms. A Flutter `TextField` stays in step, because Flutter's embedding defers its
    insets to the IME animation for its own input connection. We measured the same with texture layer hybrid
    composition (`initSurfaceAndroidView`), which also loses accessibility for SurfaceViews and breaks the text
    magnifier ([Flutter docs](https://docs.flutter.dev/platform-integration/android/platform-views)), so the chat
    keeps hybrid composition. Repro for Flutter: a `Scaffold` (default `resizeToAvoidBottomInset`) whose body is a
    `PlatformViewLink` hosting a plain `EditText` aligned to the bottom; tap it and record the screen: the
    `EditText` reaches the keyboard's top only after the IME animation ends, while a `TextField` in the same place
    moves with it.
- **Safe areas.** The chat keeps clear of the padding its ancestors left
  ([`MediaQuery.paddingOf`](https://api.flutter.dev/flutter/widgets/MediaQueryData/padding.html), which already
  excludes what the keyboard covers): under an app bar it has no status-bar gap, above a bottom navigation bar no
  navigation-bar gap, and full screen it clears both. iOS gets this from UIKit (the view's place in its window); on
  Android the widget sends it to `PingFrontChat(windowInsets:)`.
- **Loading.** Until the native view draws its first frame, a placeholder in the chat's background colour covers it
  (no spinner).
- **Hosting.** iOS: a `UIHostingController` that becomes a child of the Flutter view controller once the view is
  in a window, so the photo picker, Safari and the report sheet present normally. Android: hybrid composition
  ([`initExpensiveAndroidView`](https://api.flutter.dev/flutter/services/PlatformViewsService/initExpensiveAndroidView.html)),
  which [the Flutter docs](https://docs.flutter.dev/platform-integration/android/platform-views) describe as full
  native fidelity and correct accessibility, at the cost of thread merging; the composer needs real IME input.
- **Android host activity.** Use `FlutterFragmentActivity` (a `ComponentActivity`), as plugins such as `local_auth`
  ask: the SDK's `PingFrontChatView` then uses the window's lifecycle and saved-state owners and the activity's
  result registry (photo picker, camera). On a `FlutterActivity` the SDK's view brings its own owners and a
  recomposer that pauses while the chat is not started, and the plugin passes a result registry backed by the plugin
  binding.
- **Offers and links.** Before `onOffer` runs, the presented chat closes whenever it is showing, also over an
  embedded chat; an embedded chat is never closed. `closeChat()` returns at once when only an embedded chat is on
  screen.
- A new `topic` recreates the native view with that topic's prefill.

## Build your own chat UI

`PingFront.conversation` is the native `conversation` for your own Flutter widgets: `states` (a stream; the
current snapshot first) or `state()`, with `messages`, `pending`, `timeline` (grouped rows, as the native chat
groups them), `team`, `canSend` and `closedReason`, `typing`, `live`, `draft`, `composerInsertion`,
`coolingDown`, `isOffline` and `isServerUnreachable`, and the actions `send`, `retry`, `discard`, `loadOlder`,
`choose`, `rate`, `open`, `setTyping`, `reload`, `markRead`, `updateDraft`, `consumeInsertion`, `photoData`,
`refreshedUrl` and `cooldownRemaining`.

Messages and the team cross the bridge as the pingfront API's JSON and are decoded in
Dart with the protocol's rules: an unknown part type is `UnknownPart`, an unknown card kind is `UnknownCard`
(`MessageCard` is the card type; `Card` would clash with Material's), unknown enum values are `unknown`, and a
malformed message is dropped. `test/parity_test.dart` and `test/fixtures_test.dart` decode every case of the
protocol's shared fixtures.

Call `reload()` when your screen appears, or from a `RefreshIndicator`: it completes when the reload has finished
(the thread loaded, or the load failed; the phase is `failed` only when there is nothing to show). Call `markRead()`
while your screen shows the thread and when new messages arrive, so the team sees Read and the unread count drops
to 0; it sends nothing when there is nothing to mark or while the app is paused. The built-in chat does both by
itself. A screen you draw does not count as a visible chat, so it gets no live updates (see parity notes).

The native outbox decides what is sent and when: draw `pending` as it says, without a retry state of your own. A
`PendingState.failed` message with a `heldFor` (`app_paused`, `verification_required`; `isHeld` is true) waits: it
goes again by itself, first, when sending reopens, and the messages behind it wait for it, so show it as waiting
rather than with Try again. `discard` removes any of them. A blocked person's messages are never held. When the server revokes the
install (`SessionRevoked`), the SDK starts over as a guest and wipes the outbox, held and failed messages included:
they are never sent under the new session.

Card actions (`open`, `choose`, `rate`) go through the native SDK, which keeps each report with its own `clientId`
and resends it until the server records it (offline, timeouts, 429 and 5xx), so a pick shows at once and is recorded
once. The native SDKs never open a `javascript:`, `data:`, `vbscript:`, `file:`, `blob:`, `about:`, `content:` or `intent:` link, and never hand one to your link handler.

When the team resets the conversation from the dashboard, the native SDK drops the thread, its messages and the
unread count and keeps the draft and the outbox (the next message starts a new thread). The native chat empties in place
(the live `thread_reset`); a screen of your own sees the empty thread on its next load.

## Language, logs, look and team actions

- `PingFrontOptions.language` and `PingFront.setLanguage('pt-BR')` set the chat's language when your app has its
  own language picker (`null` follows the system). The native SDK ignores and logs an invalid tag.
- `PingFrontOptions.logHandler` receives every native log line at or above `logLevel` as a `PingFrontLogEntry`
  (level, message and category), on the platform thread. Lines are already redacted.
- `PingFront.look()` and `PingFront.looks` give the resolved look (`ResolvedLook`): colors, header, topics with
  their texts per language (`LookTopic.toChatTopic(tag)`), the team, draft and revision.
- `PingFront.teamActions` streams "Fix it for them" actions: those not answered yet first, then each new one.
  Do the work once per `id`, then `await action.complete()` or `action.fail(message)`.

## Vendor adapters

RevenueCat, Superwall and Adapty each have an add-on plugin, so an app pulls in only the vendor it uses: the
main plugin has no vendor dependency. Add one next to `pingfront_flutter` and pass its module:

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
  pingfront_revenuecat: ^1.0.0   # or pingfront_superwall, pingfront_adapty
```

```dart
await PingFront.configure('pk_live_…', options: PingFrontOptions(modules: [PingFrontRevenueCat.module()]));
// PingFrontSuperwall.module(placements: [SuperwallPlacement('winback_offer', title: 'Come back for 50% off')])
// PingFrontAdapty.module(placements: ['winback'])
```

Why separate packages: a Flutter app's native dependencies come from the plugins in its pubspec. A Gradle flag
or a podspec subspec would not work here (the plugin is a Swift package, and Flutter generates the app's
package graph from the plugin list), and making the Dart API part of the add-on means you cannot configure an
adapter whose native code is missing. Each add-on links the native adapter (`PingFrontRevenueCat`,
`PingFrontSuperwall`, `PingFrontAdapty` from the `pingfront-ios-revenuecat`, `-superwall` and `-adapty` Swift
packages; `sh.pingfront:pingfront-revenuecat`,
`-superwall`, `-adapty` on Android) and registers a small factory that `pingfront_flutter` calls by name at
configure time (`+moduleWithOptions:` on iOS, `module(Map)` on Android). If the add-on is missing natively, the
module is skipped with a log line, never a crash.

Configure the vendor SDK yourself, before or right after `PingFront.configure`, and leave `PingFront.onOffer`
unset: when it is set, it takes offer cards instead of the adapter. What each adapter does is in
[the adapters guide](https://pingfront.sh/docs/modules#revenuecat-superwall-and-adapty) and the Android README's
[Adapters](https://github.com/pingfront/pingfront-android#adapters) section. Options that only one platform has are documented on each
Dart parameter (for example RevenueCat's `offerings` and Superwall's `identity` are iOS only). On iOS each
add-on's Swift package declares only its own vendor, so Swift Package Manager fetches only that vendor's sources.

## Offers and paywalls

The native chat sits above Flutter: on iOS a sheet over the Flutter view controller, on Android an activity over
the Flutter activity. A paywall pushed as a Flutter route while the chat is open would be hidden behind it. So
when the person taps an offer card:

1. the plugin closes the chat and waits until it is off screen (at most 2 seconds);
2. then it calls `PingFront.onOffer` with the `OfferRequest`.

```dart
PingFront.onOffer = (request) => navigatorKey.currentState?.push(
  MaterialPageRoute<void>(builder: (_) => PaywallPage(offerId: request.offerId)),
);
```

With `PingFrontOptions(closesChatForOffers: false)` the chat stays open and `onOffer` runs at once. Use that only
when your handler presents native UI that shows above the chat by itself, such as a vendor's native paywall.
Without `onOffer`, a native store module (`PingFrontModule.store`) handles offer cards.

Tests: `OfferForwarderTest` (Kotlin) and `OfferForwarderTests` (Swift, in `example/ios/RunnerTests`) check the
order (close, wait, deliver), the opt-out, and that a second tap replaces a waiting one. The Dart tests check that
the policy reaches native and that the request is decoded. On the Android emulator, tapping an offer card in the
example closed the chat and showed the Flutter paywall route (`screenshots/android-offer-paywall.png`).

## Links

`PingFront.onLink` receives every link tapped in the chat. Return `true` when you handled it (a deep link into a
route): the plugin then closes the chat so your route is on top. Return `false` and the native SDK opens the link the
way the chat opens it: an in-app Safari view or the browser for `http` and `https`, and your
app's own scheme through the system (iOS: one of its `CFBundleURLSchemes`; Android: an intent limited to your app's
package). Another app's scheme opens nothing. A `javascript:`, `data:`, `vbscript:`, `file:`, `blob:`, `about:`,
`content:` or `intent:` link never reaches `onLink`: the native SDK refuses it first.

The plugin opens no link itself and keeps no timer: the native SDKs' `onLink` is async, so the plugin hands Dart's
answer back and the native SDK opens whatever Dart declines, with the shared link-scheme rule. The handler may be
async; the native SDK waits up to 10 seconds, then treats no answer (or a throw) as `false`: the link opens natively
and a later `true` no longer closes the chat. A declined link keeps the chat open. A link card is reported to the
team as it really went: opened, or failed with `cannot_open` when nothing opened it (another app's scheme, or nothing
to open it).

Tests: `LinkForwarderTest` (Kotlin) checks that Dart's answer is handed back, only a handled link closes the chat,
and a wait the SDK cancelled closes nothing; the cap, the default open and the reported outcome are tested in the
native SDKs (`SavedLinkTests`, `SavedLinkTapTest`), and the rule itself in `LinkURLRuleTests`, `LinkUrlRuleTest` and
`UiSafetyTest`.

```dart
PingFront.onLink = (uri) {
  if (uri.scheme != 'myapp') return false;
  router.go(uri.path);
  return true;
};
```

## Saved links into your screens

The team can send link cards that open a screen of your app. Register the screens this build can open, and open
them in `onScreen`:

```dart
await PingFront.registerScreens(const [
  AppScreen('settings.sound', title: 'Sound settings'), // the title is for the team's dashboard only
  AppScreen('plans/yearly'),
]);
PingFront.onScreen = (screen) {
  navigatorKey.currentState?.pushNamed(screen.id, arguments: screen.params);
  return true; // false: the app can't open it now
};
```

- Ids match `^[A-Za-z0-9][A-Za-z0-9_./:-]{0,99}$`: a bad id throws an `ArgumentError` in a debug build and is
  dropped in a release build. Each id counts once, at most 200. Registering sends nothing; the native SDK sends the
  list with the sessions it starts anyway.
- Return `true` when the screen opened; the presented chat then closes. `false`, a throw or no handler counts as not
  handled, and the team sees the link failed. The tap waits for your answer, up to 10 seconds (the native SDKs own
  the cap); a later answer is ignored and closes nothing.
- A card for a screen this build didn't register opens its URL instead (through `onLink`). `LinkCard.screen` and
  `LinkCard.savedLinkId` carry the same in `PingFront.conversation`.

## Links into the chat

A link can open the chat: an email from your team, a "Message us" QR code, a "Chat with us in the app" button on your
website, a Shortcut, or a push you send through your own provider. Add `pingfront=chat` (or `pingfront=report` for
the bug report) to a URL your app already opens (`https://example.com/help?pingfront=chat` on your universal link
or App Link domain, `myapp://support?pingfront=chat&topic=billing` on your custom scheme) and pass incoming links
to `PingFront.handleUrl`:

```dart
final handled = await PingFront.handleUrl(uri.toString());
if (!handled) router.go(uri.path); // not a chat link: route it as before
```

It completes with `true` only when the URL was a chat link: the native SDK opened the chat or the bug report,
exactly as `openChat` and `openReport` do. Everything else is `false`. `topic` applies only when it is the id of
one of the chat's topics; other parameters are ignored, and a link never puts text in the composer. The call sends
nothing; the session starts when the chat appears. It is safe before `configure`: the native SDK keeps the link
and opens it right after `configure`. The plugin claims no domain or scheme; your app's own intent filters,
associated domains and URL types stay yours. The rules every SDK shares are in
[Chat links](https://pingfront.sh/docs/chat-links).

`handleUrl` needs the absolute URL (`scheme://…`): a route path such as `/help?pingfront=chat` is not a chat link.
Flutter's built-in deep linking (`flutter_deeplinking_enabled`) gives your router a route, which may not carry the
scheme and host, so read incoming links with a plugin that gives you the whole URI, such as
[`app_links`](https://pub.dev/packages/app_links), and pass each one to `handleUrl` before your router:

```dart
final links = AppLinks();
links.uriLinkStream.listen((uri) async {
  if (await PingFront.handleUrl(uri.toString())) return;
  router.go(uri.path);
});
```

Check `app_links`' documentation for how your version delivers the link that launched the app (an initial-link
call, or the stream itself); either way, pass that link to `handleUrl` too. The plugin's own Dart tests check that
`handleUrl` forwards every string unchanged and returns the native answer, before and after `configure`; the case
table itself is tested in the native SDKs.

## Push

Forward the token and the payloads from your push library (for example `firebase_messaging`):

```dart
await PingFront.setPushToken(Platform.isIOS ? await messaging.getAPNSToken() : await messaging.getToken());
FirebaseMessaging.onMessage.listen((m) => PingFront.handlePush(m.data, opened: false));
FirebaseMessaging.onMessageOpenedApp.listen((m) => PingFront.handlePush(m.data));
```

On iOS the token is the APNs token as hex. A `pingfront` value that arrives as JSON text is decoded for you. If
your app uses `firebase_messaging`, do not also add `PingFrontModule.push()` on Android: both would register a
`FirebaseMessagingService`.

**Another push library (OneSignal, Braze, an Expo-style setup).** pingfront's pushes go to the token you pass to
`setPushToken`: the raw APNs token on iOS and the FCM token on Android, never the library's own subscription id.
Wherever that library hands you a received or tapped notification's payload, pass it to
`handlePush(data, opened: …)`, which returns `false` for payloads that aren't pingfront's;
`isPingFrontPush(data)` tells them apart without acting. A push you send yourself through that library can
open the chat too: give it a chat link as its URL or deep link and pass the URL to `handleUrl` when it reaches your
app ([Links into the chat](#links-into-the-chat)).

## Verify

```dart
final result = await PingFront.selfCheck(); // SelfCheckResult: passed, code, line
debugPrint(result.line);
// PingFront self-check: PASS
// PingFront self-check: FAIL <code>: <what to do>   (key_invalid, key_unknown, network, app_paused, timeout, …)
```

It runs the native SDK's `selfCheck()`: it creates a session if needed, sends "Setup check from" plus your app's
name, and waits for the server, so the message shows up in your inbox. The same check runs from the launch
arguments coding agents use (debug builds):

```sh
xcrun simctl launch --console booted <bundle id> -PingFrontSelfCheck          # iOS: the native SDK's own check
adb shell am start -n <package>/.MainActivity --ez pingfront_selfcheck true    # Android: logcat tag PingFront
```

## Parity notes

- **Chat UI:** native on both platforms, nothing drawn in Dart, presented (`openChat`) or embedded
  (`PingFrontChatView`).
- **Embedded chat hosting (Android):** the platform view is the Android SDK's `PingFrontChatView`, which owns its
  composition, lifecycle and saved-state owners (its own in a `FlutterActivity`, which has none) and its visibility
  counting. The plugin sets only its insets (`Insets.Padding`, Flutter's safe-area padding), keeps the composition
  while Flutter takes the view off screen (`DisposeOnLifecycleDestroyed` on the activity, disposed with the
  widget), and, on a `FlutterActivity`, an activity result registry backed by the plugin binding.
- **Own UI visibility:** neither native SDK has a public call for a custom chat UI to say it is on screen, so
  `conversation` gives no live updates for a screen drawn in Dart (the same as natively). Read receipts come from
  `conversation.markRead()`.
- **`usesAppBadge()`:** both platforms read the SDK (`PingFront.usesAppBadge` on Android).
- **`handleBackgroundPush`:** iOS only; on Android the push module's service handles silent pushes.
- **`PingFrontLogEntry.category`:** both platforms, with the same area names.
- **`ConversationState.failureCode`:** iOS gives the error code; Android reports only whether the device looked
  offline (`network`, else `unexpected`). `awaitingApproval` (Ask to Buy) is iOS only.
- **Vendor adapter options:** Android's adapters take placements (and kinds) only (the Android `RevenueCat` module
  is an object with no options); RevenueCat's `offerings` and
  `presentsPaywalls`, Superwall's products, params, `identity` and `reportsEntitlement`, and Adapty's `identity`,
  `observerMode`, `presentsPaywalls` and `reportsEntitlement` are iOS only. The iOS adapters' own `onOffer`
  fallback (returning an outcome) is not bridged: use `PingFront.onOffer` for your own paywall.
- **`setPushToken(null)`:** clears the token on both platforms.
- **`Entitlement.expiresAt` and `gracePeriodEndsAt`:** Android only; iOS takes `renewsAt`.
- **`ChatAppearance.useDynamicColor`:** Android only.
- **`selfCheck()`:** the native SDKs' own check on both platforms, with the same codes and advice.
- **Debug previews** (`-PingFrontPreview`): the iOS launch argument works as in a native app.
- **`isConfigured` and launch extras (Android):** `state()` reads the SDK's `isConfigured`, and the SDK keeps the
  launch intent until `configure` runs, so `--ez pingfront_selfcheck true` works in a Flutter app (see
  [Verify](#verify)).

## Run the example

Clockwise (`example/`) is a small alarm app that uses the plugin the way an app would. Run it with your app's test
key from **Settings › Keys** in the pingfront dashboard:

```sh
cd example
flutter run --dart-define=PINGFRONT_KEY=pk_test_…   # PINGFRONT_DEMO=help starts on the Help tab
```

Clockwise has two tabs: Alarms (the presented chat, the bug report and developer rows: the chat in a screen under an
app bar, full screen, in a dialog, sign in and out, the chat language and notifications) and Help (the embedded
chat). The defines are compile-time: pass them to every `flutter run` and `flutter build`. `PINGFRONT_LANGUAGE=ar`
shows the chat in Arabic, and with `PINGFRONT_DEMO=chat` debug builds run the self-check (a real message) and open
the chat. Reply from the dashboard and the reply appears in the open chat. Debug builds on a loaded emulator can
take 20 seconds or more to show the first frame; use `flutter build apk --profile` (same defines) for screenshots
and timing.

## Develop

| Gate | Command (in `pingfront_flutter/` unless noted) |
| --- | --- |
| Dart tests (mocked Pigeon host API) | `flutter test` |
| Lints, strict | `flutter analyze` (also in `example/`) |
| Format | `dart format --set-exit-if-changed lib test pigeons ../example` (the generated `messages.g.dart` is formatted by `tool/pigeon.sh`) |
| Kotlin unit tests | `cd ../example/android && ./gradlew :pingfront_flutter:testDebugUnitTest` (after a first `flutter build apk` in `example/`, which writes the Gradle wrapper) |
| Swift unit tests | `cd ../example && flutter build ios --simulator --config-only`, then `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'id=<simulator>' -only-testing:RunnerTests` |
| Add-on Dart tests | `flutter test` and `flutter analyze` in `../pingfront_revenuecat`, `../pingfront_superwall`, `../pingfront_adapty` |
| Builds | `cd ../example && flutter build ios --simulator --debug` and `flutter build apk --debug` |

After changing `pigeons/messages.dart`, run `tool/pigeon.sh`.

Swift code is in Swift 5 language mode, because the Pigeon-generated code and Flutter's iOS embedding have no
concurrency annotations. Classes Flutter creates outside any actor are not isolated and keep their SDK work in
`@MainActor` extensions; the plugin's own code has no `@unchecked Sendable`, `nonisolated(unsafe)` or `assumeIsolated`
(the Pigeon-generated `Messages.g.swift` declares its codec `@unchecked Sendable`, as Pigeon writes it). Kotlin
compiles with `allWarningsAsErrors`.

Known build output that does not come from this plugin:

- **Android:** Flutter 3.47's Gradle plugin needs AGP's old DSL (`android.newDsl=false`). With it, KGP prints
  "Deprecated 'org.jetbrains.kotlin.android' plugin usage" for every Flutter module, Flutter's `integration_test`
  build script (where an app uses it) prints one DSL deprecation, and Gradle reports "Project object as a dependency notation" from
  Flutter's `PluginHandler`. A fresh `flutter create` app prints the same. AGP's own option and variant-API
  warnings are suppressed by name in `example/android/gradle.properties`.
- **iOS:** `appintentsmetadataprocessor` logs "Metadata extraction skipped" for every app without App Intents.
