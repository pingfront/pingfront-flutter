import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'brand.dart';
import 'chat_view.dart'
    show chatViewShown, primeChatViewLook, resetChatViewLook;
import 'codec.dart';
import 'conversation.dart';
import 'look.dart';
import 'messages.g.dart';
import 'messages.g.dart'
    as streams
    show conversationStates, events, looks, teamActions, unreadCounts;
import 'models.dart';
import 'results.dart';
import 'thread.dart' show LinkScreen;

/// Called when the person taps an offer card. Show your paywall for [OfferRequest.offerId].
///
/// With [PingFrontOptions.closesChatForOffers] on (the default), the native chat is already closed
/// when this runs, so a paywall pushed as a Flutter route is on top.
typedef OfferHandler = FutureOr<void> Function(OfferRequest request);

/// Called for every link the person taps in the chat. Return `true` when you handled it (for
/// example a deep link into a Flutter route); the chat then closes so your route is on top.
/// Return `false` and the link opens the way the chat would have opened it. The chat waits for your
/// answer up to 10 seconds; no answer by then (or a throw) counts as `false`, and a later answer is
/// ignored. A link card then reports what really happened: opened, or failed when nothing could
/// open it.
typedef LinkHandler = FutureOr<bool> Function(Uri uri);

/// Opens a screen of your app from a link card (a saved link the team sent), for screens registered with
/// [PingFront.registerScreens]. Navigate there and return `true`; return `false` when the app can't open it now,
/// and the team sees the link failed. A throw counts as `false`. The tap waits for your answer, up to 10 seconds; a
/// later answer is ignored (it neither counts nor closes the chat). A handled screen closes the presented chat, as a
/// handled link does.
typedef ScreenHandler = FutureOr<bool> Function(LinkScreen screen);

final RegExp _screenId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9_./:-]{0,99}$');

/// The seam between the Dart API and the platform: Pigeon in apps, a fake in tests.
abstract interface class PingFrontPlatform {
  /// The host API (Dart to native).
  PingFrontHostApi get host;

  /// SDK events from native.
  Stream<EventMessage> events();

  /// The unread count from native: the current value first, then every change.
  Stream<int> unreadCounts();

  /// Team actions from native: those not answered yet first, then each new one.
  Stream<TeamActionMessage> teamActions();

  /// Conversation snapshots from native: the current one first, then every change.
  Stream<ConversationMessage> conversationStates();

  /// The resolved look from native: the current value first, then every change.
  Stream<LookMessage> looks();

  /// Registers the handler for calls from native (offer and link taps).
  void setUpFlutterApi(PingFrontFlutterApi? api);
}

/// The production platform: the Pigeon channels.
final class PigeonPingFrontPlatform implements PingFrontPlatform {
  /// Creates the platform.
  PigeonPingFrontPlatform();

  @override
  final PingFrontHostApi host = PingFrontHostApi();

  @override
  Stream<EventMessage> events() => streams.events();

  @override
  Stream<int> unreadCounts() => streams.unreadCounts();

  @override
  Stream<TeamActionMessage> teamActions() => streams.teamActions();

  @override
  Stream<ConversationMessage> conversationStates() =>
      streams.conversationStates();

  @override
  Stream<LookMessage> looks() => streams.looks();

  @override
  void setUpFlutterApi(PingFrontFlutterApi? api) =>
      PingFrontFlutterApi.setUp(api);
}

/// In-app support chat and proactive messages ("pings"), on top of the native iOS and Android
/// SDKs.
///
/// ```dart
/// await PingFront.configure('pk_live_…');
/// await PingFront.identify(userId: user.id, name: user.name);
/// await PingFront.openChat(topic: ChatTopic.billing);
/// ```
///
/// Nothing is sent at configure or launch: a session starts on the first chat open, listened
/// moment, push open, bug report or [prepare]. The chat itself is native (iMessage-style on iOS,
/// Google Messages-style on Android) and is presented over your Flutter view.
abstract final class PingFront {
  static PingFrontPlatform _platform = PigeonPingFrontPlatform();
  static OfferHandler? _onOffer;
  static LinkHandler? _onLink;
  static ScreenHandler? _onScreen;
  static PingFrontLogHandler? _logHandler;
  static PingFrontConversation? _conversation;
  static bool _closesChatForOffers = true;
  static bool _flutterApiReady = false;
  static Stream<PingFrontEvent>? _events;
  static Stream<ResolvedLook>? _looks;
  static Stream<TeamAction>? _teamActions;
  static ValueNotifier<int>? _unread;
  static StreamController<int>? _unreadChanges;
  // Kept for the lifetime of the app: the badge is meant to stay current.
  // ignore: cancel_subscriptions
  static StreamSubscription<int>? _unreadSubscription;

  /// Replaces the platform, for tests. Resets every cached stream and handler.
  @visibleForTesting
  static set platform(PingFrontPlatform platform) {
    _platform = platform;
    _onOffer = null;
    _onLink = null;
    _onScreen = null;
    _logHandler = null;
    _conversation = null;
    resetChatViewLook();
    _closesChatForOffers = true;
    _flutterApiReady = false;
    _events = null;
    _looks = null;
    _teamActions = null;
    unawaited(_unreadSubscription?.cancel());
    _unreadSubscription = null;
    unawaited(_unreadChanges?.close());
    _unreadChanges = null;
    _unread?.dispose();
    _unread = null;
  }

  /// Starts the SDK with a public app key (`pk_live_…` or `pk_test_…`).
  ///
  /// Pass `null` to have the native SDK read the key from the app instead: `PingFrontAppKey` in
  /// Info.plist on iOS, the `pingfront.app_key` meta-data in the manifest on Android. The key is
  /// checked offline; nothing is sent. A mistyped key never fails silently: debug
  /// builds show a red banner in the chat and report a [ConfigurationProblem], release builds
  /// disable the SDK. Calling it again restarts the native SDK with the new options.
  static Future<void> configure(
    String? appKey, {
    PingFrontOptions options = const PingFrontOptions(),
  }) {
    _closesChatForOffers = options.closesChatForOffers;
    _logHandler = options.logHandler;
    _ensureFlutterApi();
    return _call(() async {
      await _platform.host.configure(
        encodeConfigure(
          appKey,
          options,
          handlesOffers: _onOffer != null,
          handlesLinks: _onLink != null,
        ),
      );
      // The embedded chat's placeholder uses the look's background from its first frame.
      await primeChatViewLook();
    });
  }

  /// The current state: configured, unread count, chat visibility, person, problem.
  static Future<PingFrontState> state() =>
      _call(() async => decodeState(await _platform.host.state()));

  /// Names the person. Unverified: they keep one thread per install until verified.
  ///
  /// Returns at once; changes are coalesced and sent once a session exists.
  static Future<void> identify({
    required String userId,
    String? name,
    String? email,
  }) => _call(() => _platform.host.identify(userId, name, email));

  /// Verifies the person with an HS256 token signed by your backend (claims `sub`, `exp`,
  /// optional `name` and `email`). Verified people get one thread across devices.
  static Future<void> identifyWithToken(String token) =>
      _call(() => _platform.host.identifyWithToken(token));

  /// Adds or updates traits (merged; at most 30, keys up to 64 and values up to 512 characters).
  static Future<void> setTraits(Map<String, String> traits) =>
      _call(() => _platform.host.setTraits(traits));

  /// Reports the person's subscription state.
  static Future<void> setEntitlement(Entitlement entitlement) => _call(
    () => _platform.host.setEntitlement(encodeEntitlement(entitlement)),
  );

  /// Reports the offers your app can show, so the team can send offer cards for them. Replaces
  /// the app's earlier slots; slots from native modules stay. An empty list clears yours.
  static Future<void> setOffers(List<OfferSlot> offers) =>
      _call(() => _platform.host.setOffers(offers.map(encodeSlot).toList()));

  /// Logs the person out on this device: forgets identity, traits and the thread. The server is
  /// told (retried until it succeeds). The next session is a new guest.
  static Future<void> logout() => _call(_platform.host.logout);

  /// Erases every server-side record of the person, then wipes this device. Safe to retry.
  static Future<void> eraseMyData() => _call(_platform.host.eraseMyData);

  /// Everything the server holds about the person (`GET /me/export`): a JSON document, returned as
  /// the text the server sent, so the app can save or share it as is (or `jsonDecode` it).
  static Future<String> exportMyData() => _call(_platform.host.exportMyData);

  /// Creates the session now instead of lazily (for example right after login).
  static Future<void> prepare() => _call(_platform.host.prepare);

  /// Presents the native chat over the Flutter view. With a topic, its prefill goes into the
  /// composer.
  static Future<void> openChat({ChatTopic? topic}) => _call(
    () => _platform.host.openChat(topic == null ? null : encodeTopic(topic)),
  );

  /// Closes the chat. Completes once it is off screen.
  static Future<void> closeChat() => _call(_platform.host.closeChat);

  /// Reports an app moment (`paywall_closed`, `trial_cancelled`, …). Only moments a play listens
  /// to are sent. Values are strings (up to 256 characters), numbers or booleans.
  static Future<MomentResult> moment(
    String name, [
    Map<String, Object> props = const {},
  ]) async {
    for (final entry in props.entries) {
      final value = entry.value;
      if (value is! String && value is! num && value is! bool) {
        throw ArgumentError.value(
          value,
          'props["${entry.key}"]',
          'must be a String, num or bool',
        );
      }
    }
    return _call(
      () async => decodeMomentResult(await _platform.host.moment(name, props)),
    );
  }

  /// Forwards the push token: the APNs device token as hex on iOS (for example from
  /// `FirebaseMessaging.instance.getAPNSToken()`), the FCM token on Android. `null` clears it.
  static Future<void> setPushToken(String? token) =>
      _call(() => _platform.host.setPushToken(token));

  /// Handles a push payload. Returns true when it was ours.
  ///
  /// Pass `opened: true` for a notification tap (the chat opens), `false` for one received while
  /// the app runs (the unread count updates). `data` is the payload as your push library gives
  /// it: the APNs `userInfo` on iOS, the FCM data map on Android.
  static Future<bool> handlePush(
    Map<String, Object?> data, {
    bool opened = true,
  }) => _call(() => _platform.host.handlePush(_decodePushData(data), opened));

  /// True when [data] is a push payload from us (any version).
  static Future<bool> isPingFrontPush(Map<String, Object?> data) =>
      _call(() => _platform.host.isPingFrontPush(_decodePushData(data)));

  /// Opens the bug report flow (screenshot and markup with the reports module, text otherwise).
  static Future<void> openReport({String? prefill}) =>
      _call(() => _platform.host.openReport(prefill));

  /// Opens the chat, or the bug report, from a chat link your app received. Returns true only
  /// when it was one.
  ///
  /// A chat link is any URL your app routes here whose query has `pingfront=chat` or
  /// `pingfront=report`, on your own universal link or App Link domain or your custom scheme
  /// (`https://example.com/help?pingfront=chat`, `myapp://support?pingfront=chat&topic=billing`).
  /// The SDK claims no domain or scheme of its own. `topic` is used only when it is the id of one
  /// of the chat's topics; other parameters are ignored, and a link never puts text in the
  /// composer. Any other URL returns false, so route it yourself.
  ///
  /// Handling a link is the same as [openChat] or [openReport]: the session starts when the chat
  /// appears, and this call sends nothing. It is safe before [configure]: the native SDK keeps the
  /// link (the last one wins) and opens it right after [configure].
  static Future<bool> handleUrl(String url) =>
      _call(() => _platform.host.handleUrl(url));

  /// Sends a bug report with an optional PNG or JPEG screenshot.
  static Future<void> reportBug(String text, {Uint8List? screenshot}) =>
      _call(() => _platform.host.reportBug(text, screenshot));

  /// Runs the native SDK's setup check: creates a session if needed, sends "Setup check from" plus
  /// the app's name, waits for the server, and returns whether it passed, the failure code, and the
  /// one line (`PingFront self-check: PASS` or `PingFront self-check: FAIL <code>: <what to do>`).
  /// It sends a real message to your inbox.
  static Future<SelfCheckResult> selfCheck() => _call(() async {
    final result = await _platform.host.selfCheck();
    return SelfCheckResult(
      passed: result.passed,
      code: result.passed ? null : (result.code ?? 'unexpected'),
      line: result.line,
    );
  });

  /// The chat's language when your app has its own language picker: a BCP 47 tag such as `de` or
  /// `pt-BR`, or `null` to follow the app's and the system's language. The chat UI, the SDK's own
  /// strings, the team's localized texts and the language the server writes in all follow it. Call it
  /// again whenever the person picks a language; the native SDK ignores (and logs) an invalid tag.
  static Future<void> setLanguage(String? languageTag) =>
      _call(() => _platform.host.setLanguage(languageTag));

  /// The chat's language set with [setLanguage] or [PingFrontOptions.language], or `null`.
  static Future<String?> language() => _call(_platform.host.language);

  /// The person's store account token, once a session exists (`null` before).
  ///
  /// A lowercase UUID string on both platforms. iOS: pass it as `appAccountToken` in your own
  /// StoreKit purchases so App Store notifications match the person. Android: the token billing
  /// modules pass as Play's `obfuscatedAccountId`. The store modules and vendor adapters use it
  /// for you.
  static Future<String?> storeAccountToken() =>
      _call(_platform.host.storeAccountToken);

  /// True when the dashboard turned on the app icon badge (`features.appBadge`; off by default: the
  /// badge is your app's), on iOS and Android. On Android the push module sets launcher badges itself
  /// when it is on.
  static Future<bool> usesAppBadge() => _call(_platform.host.usesAppBadge);

  /// Asks the person for notification permission. iOS: alert and sound (and badge when the dashboard
  /// turned it on), then registers for remote notifications; forward the token with [setPushToken].
  /// Android 13+: the `POST_NOTIFICATIONS` runtime permission (declared by `pingfront-push`; add it to
  /// your manifest without that module). Earlier Android versions need no prompt and return `true`.
  /// Returns `true` when notifications are allowed.
  static Future<bool> requestPushAuthorization() =>
      _call(_platform.host.requestPushAuthorization);

  /// iOS: handles a silent push (`content-available: 1`) that arrived in the background, for example a
  /// new chat look. Returns `null` when the payload isn't ours. It shows nothing and never starts a
  /// session. Android: always `null`; the push module handles data messages.
  static Future<BackgroundPushResult?> handleBackgroundPush(
    Map<String, Object?> data,
  ) async {
    final result = await _call(
      () => _platform.host.handleBackgroundPush(_decodePushData(data)),
    );
    return switch (result) {
      null => null,
      'newData' => BackgroundPushResult.newData,
      'failed' => BackgroundPushResult.failed,
      _ => BackgroundPushResult.noData,
    };
  }

  /// The resolved chat look, for your own chat UI or to match your screens to it.
  static Future<ResolvedLook> look() =>
      _call(() async => decodeLook(await _platform.host.look()));

  /// The resolved chat look: the current value first, then every change.
  static Stream<ResolvedLook> get looks =>
      _looks ??= _platform.looks().map(decodeLook);

  /// Team actions your app has to do ("Fix it for them"). Actions not answered yet arrive first, then
  /// each new one once. Do the work, then call [TeamAction.complete] or [TeamAction.fail].
  ///
  /// ```dart
  /// PingFront.teamActions.listen((action) async {
  ///   if (action.actionId == 'repair_sync') {
  ///     await sync.repair();
  ///     await action.complete();
  ///   } else {
  ///     await action.fail("This version of the app can't do ${action.name}.");
  ///   }
  /// });
  /// ```
  static Stream<TeamAction> get teamActions =>
      _teamActions ??= _platform.teamActions().map(_teamAction);

  /// The thread and its actions, for apps that draw their own chat UI.
  static PingFrontConversation get conversation =>
      _conversation ??= PingFrontConversation(
        () => _platform.host,
        () => _platform.conversationStates(),
      );

  static TeamAction _teamAction(TeamActionMessage m) => TeamAction(
    id: m.id,
    actionId: m.actionId,
    name: m.name,
    fields: m.fields,
    days: m.days,
    until: m.untilMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m.untilMs!, isUtc: true),
    ackRequired: m.ackRequired,
    createdAt: DateTime.fromMillisecondsSinceEpoch(m.createdAtMs, isUtc: true),
    expiresAt: DateTime.fromMillisecondsSinceEpoch(m.expiresAtMs, isUtc: true),
    answer: (failure) => _call(
      () => failure == null
          ? _platform.host.completeTeamAction(m.id)
          : _platform.host.failTeamAction(m.id, failure),
    ),
  );

  /// Called when the person taps an offer card. When unset, a native store module handles it.
  static OfferHandler? get onOffer => _onOffer;

  static set onOffer(OfferHandler? handler) {
    _onOffer = handler;
    _syncHandlers();
  }

  /// Called for every link the person taps in the chat. See [LinkHandler].
  static LinkHandler? get onLink => _onLink;

  static set onLink(LinkHandler? handler) {
    _onLink = handler;
    _syncHandlers();
  }

  /// Called for a link card that opens a screen this build registered. See [ScreenHandler].
  static ScreenHandler? get onScreen => _onScreen;

  static set onScreen(ScreenHandler? handler) {
    _onScreen = handler;
    _ensureFlutterApi();
    unawaited(
      _call(() => _platform.host.setScreenHandler(handler != null))
          .catchError((Object _) {}),
    );
  }

  /// Registers the screens of your app that the team's saved links can open (https://pingfront.sh/docs/offers#saved-links).
  ///
  /// Call it at launch, before or after [configure]; a later call replaces the list. Registering sends nothing:
  /// the native SDK sends the list with the sessions it starts anyway. Ids must match
  /// `^[A-Za-z0-9][A-Za-z0-9_./:-]{0,99}$`: in a debug build a bad id throws an [ArgumentError], in a release
  /// build it is dropped. Each id counts once (the first wins), at most 200; titles are cut to 60 characters.
  ///
  /// ```dart
  /// await PingFront.registerScreens(const [
  ///   AppScreen('settings.sound', title: 'Sound settings'),
  ///   AppScreen('plans/yearly'),
  /// ]);
  /// PingFront.onScreen = (screen) {
  ///   navigatorKey.currentState?.pushNamed(screen.id, arguments: screen.params);
  ///   return true;
  /// };
  /// ```
  static Future<void> registerScreens(List<AppScreen> screens) {
    final bad = [
      for (final screen in screens)
        if (!_screenId.hasMatch(screen.id)) screen.id,
    ];
    if (bad.isNotEmpty && kDebugMode) {
      throw ArgumentError.value(
        bad,
        'screens',
        r'screen ids must match ^[A-Za-z0-9][A-Za-z0-9_./:-]{0,99}$',
      );
    }
    return _call(
      () => _platform.host.registerScreens([
        for (final screen in screens)
          if (_screenId.hasMatch(screen.id))
            AppScreenMessage(id: screen.id, title: screen.title),
      ]),
    );
  }

  /// SDK events. New native events arrive as [PingFrontEvent.unknown].
  static Stream<PingFrontEvent> get events =>
      _events ??= _platform.events().map(decodeEvent);

  /// Unread team messages: the current value first, then every change.
  static Stream<int> get unreadCount {
    final notifier = unread;
    return Stream<int>.multi((controller) {
      controller.add(notifier.value);
      final subscription = _unreadChanges!.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = subscription.cancel;
    });
  }

  /// Unread team messages, for `ValueListenableBuilder`.
  static ValueListenable<int> get unread {
    final existing = _unread;
    if (existing != null) return existing;
    final notifier = ValueNotifier<int>(0);
    // Closed when the platform is replaced (tests); otherwise it lives as long as the app.
    // ignore: close_sinks
    final changes = StreamController<int>.broadcast();
    _unread = notifier;
    _unreadChanges = changes;
    _unreadSubscription = _platform.unreadCounts().listen((count) {
      if (count == notifier.value) return;
      notifier.value = count;
      changes.add(count);
    }, onError: (Object _) {});
    return notifier;
  }

  static void _syncHandlers() {
    _ensureFlutterApi();
    unawaited(
      _call(
        () => _platform.host.setHandlers(
          _onOffer != null,
          _closesChatForOffers,
          _onLink != null,
        ),
      ).catchError((Object _) {}),
    );
  }

  static void _ensureFlutterApi() {
    if (_flutterApiReady) return;
    _flutterApiReady = true;
    _platform.setUpFlutterApi(_FlutterSide());
  }

  static Map<String, Object?> _decodePushData(Map<String, Object?> data) {
    final value = data[Brand.pushKey];
    if (value is! String) return data;
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, Object?>) {
        return {...data, Brand.pushKey: decoded};
      }
    } on FormatException {
      // Not JSON: pass it on unchanged.
    }
    return data;
  }

  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw PingFrontException(e.code, e.message ?? e.code);
    }
  }
}

/// Receives calls from native.
final class _FlutterSide extends PingFrontFlutterApi {
  @override
  Future<void> onOffer(OfferRequestMessage request) async {
    final handler = PingFront.onOffer;
    if (handler == null) return;
    await handler(decodeOfferRequest(request));
  }

  @override
  void onChatViewShown(int viewId) => chatViewShown(viewId);

  @override
  void onLog(LogEntryMessage entry) {
    PingFront._logHandler?.call(decodeLogEntry(entry));
  }

  @override
  Future<bool> onScreen(LinkScreenMessage screen) async {
    final handler = PingFront.onScreen;
    if (handler == null) return false;
    try {
      return await handler(
        LinkScreen(id: screen.id, params: Map.of(screen.params)),
      );
    } on Object catch (error) {
      debugPrint('pingfront: the onScreen handler threw ${error.runtimeType}.');
      return false;
    }
  }

  @override
  Future<bool> onLink(String url) async {
    final handler = PingFront.onLink;
    final uri = Uri.tryParse(url);
    if (handler == null || uri == null) return false;
    try {
      return await handler(uri);
    } on Object catch (error) {
      debugPrint('pingfront: the onLink handler threw ${error.runtimeType}.');
      return false;
    }
  }
}

/// The host API, for the embedded chat widget (not exported).
PingFrontHostApi chatViewHost() => PingFront._platform.host;
