// Clockwise: a small alarm app that integrates pingfront the way a customer would.
//
// Run it with your app's test key (see README.md, "Run the example"):
//   flutter run --dart-define=PINGFRONT_KEY=pk_test_…
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';

/// Your app's key (`--dart-define=PINGFRONT_KEY=…`). The default is the test key a local development API seeds.
const appKey = String.fromEnvironment(
  'PINGFRONT_KEY',
  defaultValue: 'pk_test_abcdefghijklmnopqrstuvvd',
);

/// A local development API: `PINGFRONT_API` as a full URL, or `PINGFRONT_PORT` on this machine. Neither set
/// means pingfront.sh.
String? apiUrl() {
  const url = String.fromEnvironment('PINGFRONT_API');
  if (url.isNotEmpty) return url;
  const port = String.fromEnvironment('PINGFRONT_PORT');
  if (port.isEmpty) return null;
  // The Android emulator reaches the host machine at 10.0.2.2.
  final host = !kIsWeb && Platform.isAndroid ? '10.0.2.2' : 'localhost';
  return 'http://$host:$port/v1';
}

const _accent = Color(0xFF3550E6);

/// Who keeps the embedded chat clear of the keyboard: on Android Flutter (the Scaffold resizes, the default); on
/// iOS the chat itself (SwiftUI's keyboard safe area), so the composer follows an interactive dismissal too.
final bool resizesForKeyboard = defaultTargetPlatform != TargetPlatform.iOS;

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The paywall is a Flutter route. The plugin closes the native chat before this runs, so the
  // route is on top.
  PingFront.onOffer = (request) => navigatorKey.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => PaywallPage(offerId: request.offerId),
    ),
  );
  // Deep links in messages: clockwise://alarms opens the alarm list.
  PingFront.onLink = (uri) {
    if (uri.scheme != 'clockwise') return false;
    unawaited(
      navigatorKey.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => const AlarmsPage()),
      ),
    );
    return true;
  };
  // "Fix it for them": the team can extend the trial from the inbox. Clockwise has no trials to extend
  // in this example, so it tells the team so; a real app does the work, then calls complete().
  PingFront.teamActions.listen(
    (action) => unawaited(
      action.fail("This version of Clockwise can't do ${action.name} yet."),
    ),
  );
  // The default key exists only on a local development API: against pingfront.sh it is unknown
  // (invalid_app_key), so say how to pass a real one (README, "Run the example").
  if (apiUrl() == null && !const bool.hasEnvironment('PINGFRONT_KEY')) {
    debugPrint(
      'Clockwise: no PINGFRONT_KEY, so the default test key goes to pingfront.sh (invalid_app_key). '
      'Build with --dart-define=PINGFRONT_KEY=<your pk_test_ key>.',
    );
  }
  await PingFront.configure(
    appKey,
    options: PingFrontOptions(
      baseUrl: apiUrl(),
      logLevel: PingFrontLogLevel.debug,
      // `--dart-define=PINGFRONT_LANGUAGE=ar` shows the chat in Arabic (right to left), for screenshots.
      language: const String.fromEnvironment('PINGFRONT_LANGUAGE').isEmpty
          ? null
          : const String.fromEnvironment('PINGFRONT_LANGUAGE'),
      // The SDK's own lines, already redacted, in the Flutter console (debug builds only).
      logHandler: kDebugMode ? (entry) => debugPrint('PFLOG $entry') : null,
      topics: const [ChatTopic.billing, ChatTopic.bug, ChatTopic.idea],
      appearance: const ChatAppearance(
        accent: PingFrontColor(_accent, Color(0xFF7D91FF)),
        replyExpectation: 'Usually replies within a few hours',
      ),
      modules: const [PingFrontModule.reports(shakeToReport: false)],
    ),
  );
  await PingFront.setOffers(const [
    OfferSlot(id: 'pro_yearly', title: 'Clockwise Pro, yearly'),
  ]);
  runApp(const ClockwiseApp());
  // Debug builds, for coding agents and screenshots: `--dart-define=PINGFRONT_DEMO=chat` runs the
  // setup check (a real message from this app) and then opens the chat.
  const demo = String.fromEnvironment('PINGFRONT_DEMO');
  if (kDebugMode && demo == 'chat') {
    debugPrint((await PingFront.selfCheck()).line);
    await PingFront.openChat();
  }
}

class ClockwiseApp extends StatelessWidget {
  const ClockwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _accent,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Clockwise',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const RootPage(),
    );
  }
}

/// Two tabs: the app, and Help with the chat embedded (`PingFrontChatView`).
class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  // `--dart-define=PINGFRONT_DEMO=help` starts on the Help tab (debug and profile builds, for screenshots).
  int _tab =
      !kReleaseMode && const String.fromEnvironment('PINGFRONT_DEMO') == 'help'
      ? 1
      : 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: resizesForKeyboard,
    body: IndexedStack(index: _tab, children: const [HomePage(), HelpPage()]),
    bottomNavigationBar: ValueListenableBuilder<int>(
      valueListenable: PingFront.unread,
      builder: (context, unread, _) => NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: 'Help',
          ),
        ],
      ),
    ),
  );
}

/// The Help tab: the native chat, embedded. It is live while the tab is on screen.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => const PingFrontChatView();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription<PingFrontEvent>? _events;
  String? _status;

  @override
  void initState() {
    super.initState();
    _events = PingFront.events.listen((event) async {
      if (!mounted) return;
      if (event case MessageReceived(:final message)) {
        // The chat already shows it: no SnackBar over the embedded chat's composer (the Help tab) or the sheet.
        if ((await PingFront.state()).isChatVisible || !mounted) return;
        final author = message.authorName ?? 'Clockwise';
        // A message with only a card or a photo has no text to preview.
        final preview = message.preview.trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              preview.isEmpty
                  ? 'New message from $author'
                  : '$author: $preview',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    super.dispose();
  }

  Future<void> _selfCheck() async {
    setState(() => _status = 'Checking the setup…');
    final result = await PingFront.selfCheck();
    debugPrint(result.line);
    if (mounted) setState(() => _status = result.line);
  }

  Future<void> _signIn() async {
    await PingFront.identify(
      userId: 'riley',
      name: 'Riley',
      email: 'riley@example.com',
    );
    if (mounted) setState(() => _status = 'Signed in as Riley');
  }

  Future<void> _signOut() async {
    await PingFront.logout();
    if (mounted) setState(() => _status = 'Signed out');
  }

  /// Cycles the chat's language: the system's, German, English.
  Future<void> _nextLanguage() async {
    const order = <String?>[null, 'de', 'en'];
    final current = await PingFront.language();
    final next = order[(order.indexOf(current) + 1) % order.length];
    await PingFront.setLanguage(next);
    if (mounted) setState(() => _status = 'Chat language: ${next ?? 'system'}');
  }

  Future<void> _notifications() async {
    final allowed = await PingFront.requestPushAuthorization();
    if (mounted) {
      setState(
        () => _status = allowed
            ? 'Notifications are on'
            : 'Notifications are off',
      );
    }
  }

  Future<void> _paywallClosed() async {
    final result = await PingFront.moment('paywall_closed', {
      'screen': 'plans',
      'seconds': 42,
    });
    if (mounted) setState(() => _status = 'Moment: ${result.runtimeType}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Clockwise')),
      body: ListView(
        // A ListView given its own padding drops the safe area, so add it back, each edge on its own: a
        // foldable iPhone puts its controls on one side, so the left and right insets differ (and change).
        padding:
            MediaQuery.paddingOf(context).copyWith(top: 0) +
            const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _NextAlarm(),
          const _SectionTitle('Support'),
          ValueListenableBuilder<int>(
            valueListenable: PingFront.unread,
            builder: (context, unread, _) => ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Talk to us'),
              subtitle: const Text('Questions, bugs and ideas'),
              trailing: unread > 0
                  ? Badge(label: Text('$unread'))
                  : const Icon(Icons.chevron_right),
              onTap: () => unawaited(PingFront.openChat()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Ask about billing'),
            onTap: () =>
                unawaited(PingFront.openChat(topic: ChatTopic.billing)),
          ),
          const _SectionTitle('Pro'),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('See Clockwise Pro'),
            onTap: () => unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PaywallPage(offerId: 'pro_yearly'),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Close the paywall'),
            subtitle: const Text('Reports the paywall_closed moment'),
            onTap: () => unawaited(_paywallClosed()),
          ),
          if (!kReleaseMode) ...[
            const _SectionTitle('Developer'),
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Run the setup check'),
              onTap: () => unawaited(_selfCheck()),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Chat in a screen'),
              subtitle: const Text('Under an app bar, with a route on top'),
              onTap: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChatScreenPage(),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('Chat full screen'),
              subtitle: const Text('No app bar, no bottom bar'),
              onTap: () => unawaited(
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      resizeToAvoidBottomInset: resizesForKeyboard,
                      body: const PingFrontChatView(),
                    ),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('Chat in a dialog'),
              onTap: () => unawaited(
                showDialog<void>(
                  context: context,
                  builder: (_) => const Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(height: 520, child: PingFrontChatView()),
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in as Riley'),
              onTap: () => unawaited(_signIn()),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              subtitle: const Text('The next chat starts as a new guest'),
              onTap: () => unawaited(_signOut()),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Change the chat language'),
              subtitle: const Text('System, German, English'),
              onTap: () => unawaited(_nextLanguage()),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Turn on notifications'),
              onTap: () => unawaited(_notifications()),
            ),
          ],
          if (_status != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                _status!,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextAlarm extends StatelessWidget {
  const _NextAlarm();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: scheme.primaryContainer,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next alarm',
              style: text.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '6:30',
              style: text.displayMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Weekdays, in 8 hours 49 minutes',
              style: text.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// The app's own paywall, as a Flutter route. Offer cards in the chat open it through `onOffer`.
class PaywallPage extends StatelessWidget {
  const PaywallPage({required this.offerId, super.key});

  final String offerId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Clockwise Pro')),
      // The side insets and the home indicator: the button never sits under either.
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Wake up on your terms', style: text.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'Unlimited alarms, smart snooze and sunrise light. '
                'Cancel any time.',
              ),
              const SizedBox(height: 8),
              Text('Offer: $offerId', style: text.bodySmall),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Start the free week'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chat as a screen of the app's own navigation, with an app bar action that pushes a route over it.
class ChatScreenPage extends StatelessWidget {
  const ChatScreenPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: resizesForKeyboard,
    appBar: AppBar(
      title: const Text('Help'),
      actions: [
        IconButton(
          tooltip: 'Alarms',
          icon: const Icon(Icons.alarm),
          onPressed: () => unawaited(
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const AlarmsPage())),
          ),
        ),
      ],
    ),
    body: const PingFrontChatView(topic: ChatTopic.billing),
  );
}

class AlarmsPage extends StatelessWidget {
  const AlarmsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Alarms')),
    body: const SafeArea(
      top: false,
      child: Column(
        children: [
          ListTile(title: Text('6:30'), subtitle: Text('Weekdays')),
          ListTile(title: Text('9:00'), subtitle: Text('Weekends')),
        ],
      ),
    ),
  );
}
