import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'brand.dart';
import 'look.dart' show ResolvedLook, decodeLook;
import 'models.dart';
import 'pingfront.dart' show PingFront, chatViewHost;

/// The native chat embedded in your layout: a tab, or a screen in your navigation. On iOS it is the
/// SDK's SwiftUI `PingFrontChatView`, on Android its View `PingFrontChatView`, each hosted as a
/// platform view, so it looks and behaves exactly like the presented chat.
///
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Help')),
///   body: const PingFrontChatView(topic: ChatTopic.billing),
/// )
/// ```
///
/// The chat is visible (live updates, read receipts, no unread polling) while the view is on screen,
/// and stops when it leaves the screen, goes offstage (another tab of an `IndexedStack`, a route pushed
/// over it) or is disposed. A new [topic] recreates the chat with that topic's prefill. Configure the SDK
/// before showing it. Until the native view draws its first frame, a placeholder in the chat's background
/// colour covers it.
///
/// The keyboard: on Android, Flutter keeps the chat clear of it, as it does any widget (the `Scaffold` with the
/// default `resizeToAvoidBottomInset: true`, or a `Dialog`). On iOS the chat keeps clear of it itself with
/// SwiftUI's keyboard safe area, which also follows an interactive dismissal: give the `Scaffold`
/// `resizeToAvoidBottomInset: false` there (`defaultTargetPlatform != TargetPlatform.iOS`). The chat keeps clear
/// of the safe-area padding its ancestors left (`MediaQuery.paddingOf`), so it fits under an app bar, above a
/// bottom navigation bar and full screen alike.
class PingFrontChatView extends StatefulWidget {
  /// Creates the embedded chat. With a [topic], its prefill goes into the composer.
  const PingFrontChatView({super.key, this.topic, this.gestureRecognizers});

  /// The topic the chat opens with.
  final ChatTopic? topic;

  /// Gestures the chat claims from enclosing Flutter scrollables. `null` (the default) gives the chat
  /// every touch on it, which is what a full-screen chat needs.
  final Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers;

  /// The key of the placeholder shown until the native view's first frame.
  @visibleForTesting
  static const Key placeholderKey = ValueKey<String>(
    'pingfront.chat.placeholder',
  );

  /// The creation parameters the native factories read: the topic, and the safe-area [padding] (left,
  /// top, right, bottom in logical pixels) no ancestor consumed at the view's position.
  @visibleForTesting
  static Map<String, Object?> creationParams(
    ChatTopic? topic, [
    EdgeInsets padding = EdgeInsets.zero,
  ]) => {
    'topic': topic == null
        ? null
        : {
            'id': topic.id,
            'label': topic.label,
            'symbol': topic.symbol.name,
            'prefill': topic.prefill,
          },
    'padding': [padding.left, padding.top, padding.right, padding.bottom],
  };

  @override
  State<PingFrontChatView> createState() => _PingFrontChatViewState();
}

/// The embedded chats waiting for their first native frame, by platform view id.
final Map<int, VoidCallback> _waitingForFirstFrame = {};

/// Called from native when an embedded chat drew its first frame.
void chatViewShown(int viewId) => _waitingForFirstFrame.remove(viewId)?.call();

/// The resolved look, for placeholders (its background is the chat's own). Read from native when the SDK is
/// configured, so a chat view shown right after has it at once; kept current while a placeholder shows.
ResolvedLook? _cachedLook;

/// Reads the resolved look from native for placeholders (the plugin calls it after configure).
Future<void> primeChatViewLook() async {
  try {
    _cachedLook = decodeLook(await chatViewHost().look());
  } on Object {
    // Not configured yet, or a test platform: the SDK's default background is used.
  }
}

/// Forgets the cached look, when the platform is replaced (tests).
void resetChatViewLook() => _cachedLook = null;

class _PingFrontChatViewState extends State<PingFrontChatView> {
  static final Set<Factory<OneSequenceGestureRecognizer>> _allGestures = {
    const Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
  };

  bool _onstage = true;
  int? _viewId;
  bool _shown = false;
  EdgeInsets _padding = EdgeInsets.zero;
  EdgeInsets? _sentPadding;
  ResolvedLook? _look = _cachedLook;
  StreamSubscription<ResolvedLook>? _looks;

  /// The topic goes to the first native view only. A view Flutter recreates later (after another tab or a route
  /// over it) continues the same chat, so its prefill is not inserted again.
  bool _topicApplied = false;

  @override
  void initState() {
    super.initState();
    // While the placeholder shows, it follows the look (published while the app runs, or the first read).
    _looks = PingFront.looks.listen((look) {
      _cachedLook = look;
      if (mounted) setState(() => _look = look);
    }, onError: (Object _) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offstage (a tab an IndexedStack keeps alive, a route under another): no native view, so the chat is
    // not "on screen" and messages are not marked read behind the person's back. The thread and draft come
    // back from the SDK when the view does.
    final onstage =
        TickerMode.valuesOf(context).enabled && Visibility.of(context);
    if (!onstage && _onstage) _forgetView();
    _onstage = onstage;
    _padding = MediaQuery.paddingOf(context);
    _sendPadding();
  }

  @override
  void didUpdateWidget(PingFrontChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new topic makes a new native view, which takes it.
    if (oldWidget.topic != widget.topic) {
      _forgetView();
      _topicApplied = false;
    }
  }

  @override
  void dispose() {
    _forgetView();
    unawaited(_looks?.cancel());
    super.dispose();
  }

  void _forgetView() {
    final id = _viewId;
    if (id != null) _waitingForFirstFrame.remove(id);
    _viewId = null;
    _shown = false;
    _sentPadding = null;
  }

  void _viewCreated(int id) {
    _viewId = id;
    _topicApplied = true;
    _sentPadding = _padding;
    _waitingForFirstFrame[id] = () {
      if (!mounted || _viewId != id) return;
      setState(() => _shown = true);
      // The look only colours the placeholder.
      unawaited(_looks?.cancel());
      _looks = null;
    };
  }

  /// Android: Flutter's inset model hands each widget the padding its ancestors left
  /// (`MediaQuery.padding`, which already excludes what the keyboard covers). The native chat gets exactly
  /// that. iOS reads the same from UIKit.
  void _sendPadding() {
    final id = _viewId;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (id == null || _padding == _sentPadding) return;
    _sentPadding = _padding;
    unawaited(
      chatViewHost()
          .setChatViewPadding(
            id,
            _padding.left,
            _padding.top,
            _padding.right,
            _padding.bottom,
          )
          .catchError((Object _) {}),
    );
  }

  /// The chat's background: the resolved look's, or until it is read, the SDK's default chat background on
  /// this platform (`ResolvedLook` defaults: iOS white / #1C1C1E, Android white / #131316).
  Color _placeholderColor(BuildContext context) {
    final look = _look;
    final dark = switch (look?.scheme ?? ChatScheme.auto) {
      ChatScheme.dark => true,
      ChatScheme.light => false,
      ChatScheme.auto =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
    if (look != null) {
      return dark ? look.background.dark : look.background.light;
    }
    if (!dark) return const Color(0xFFFFFFFF);
    return defaultTargetPlatform == TargetPlatform.iOS
        ? const Color(0xFF1C1C1E)
        : const Color(0xFF131316);
  }

  @override
  Widget build(BuildContext context) {
    if (!_onstage) return const SizedBox.expand();
    final view = _platformView(context);
    if (_shown) return view;
    return Stack(
      fit: StackFit.expand,
      children: [
        view,
        IgnorePointer(
          child: ColoredBox(
            key: PingFrontChatView.placeholderKey,
            color: _placeholderColor(context),
          ),
        ),
      ],
    );
  }

  Widget _platformView(BuildContext context) {
    final params = PingFrontChatView.creationParams(
      _topicApplied ? null : widget.topic,
      _padding,
    );
    final gestures = widget.gestureRecognizers ?? _allGestures;
    // A new topic makes a new native view: the native chat takes its topic once, when it appears.
    final key = ValueKey<ChatTopic?>(widget.topic);
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        // UIKit derives the safe area, keyboard included, from where the view sits in its window.
        return UiKitView(
          key: key,
          viewType: Brand.chatViewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          gestureRecognizers: gestures,
          onPlatformViewCreated: _viewCreated,
        );
      case TargetPlatform.android:
        // Hybrid composition: the native chat gets real IME input and accessibility.
        return PlatformViewLink(
          key: key,
          viewType: Brand.chatViewType,
          surfaceFactory: (context, controller) => AndroidViewSurface(
            controller: controller as AndroidViewController,
            gestureRecognizers: gestures,
            hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          ),
          onCreatePlatformView: (creation) {
            _viewCreated(creation.id);
            final controller = PlatformViewsService.initExpensiveAndroidView(
              id: creation.id,
              viewType: Brand.chatViewType,
              layoutDirection:
                  Directionality.maybeOf(context) ?? TextDirection.ltr,
              creationParams: params,
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () => creation.onFocusChanged(true),
            )..addOnPlatformViewCreatedListener(creation.onPlatformViewCreated);
            // Hybrid composition creates the view on first layout; this only starts it early.
            unawaited(controller.create());
            return controller;
          },
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        // The native SDKs exist for iOS and Android only.
        return const SizedBox.shrink();
    }
  }
}
