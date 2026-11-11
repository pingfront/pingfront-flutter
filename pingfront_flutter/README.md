# pingfront_flutter

In-app support chat and proactive messages for Flutter apps on iOS 17+ and Android 8.0+ (API 26). The plugin
bridges the native [pingfront iOS SDK](https://github.com/pingfront/pingfront-ios) and
[Android SDK](https://github.com/pingfront/pingfront-android), so the chat is native: the Messages-style sheet on
iOS and the Google Messages-style bottom sheet on Android, presented over your Flutter view or embedded in it.

## Install

```yaml
dependencies:
  pingfront_flutter: ^1.0.0
```

- **iOS:** the plugin is a Swift package, so turn on Flutter's Swift Package Manager support
  (`flutter config --enable-swift-package-manager`) and set the deployment target to 17.0. CocoaPods is not
  supported.
- **Android:** set `minSdk = 26` and `compileSdk = 36` (or later). The native SDK comes from Maven Central
  (`sh.pingfront:pingfront`).

## Quickstart

```dart
import 'package:flutter/material.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PingFront.configure('pk_live_…'); // checks the key on the device and sends nothing
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

In a debug build, `await PingFront.selfCheck()` sends a setup check to your inbox and tells you what to fix if it
fails.

## Vendor adapters

RevenueCat, Superwall and Adapty each have an add-on package, so your app links only the vendor it uses:
[pingfront_revenuecat](https://pub.dev/packages/pingfront_revenuecat),
[pingfront_superwall](https://pub.dev/packages/pingfront_superwall) and
[pingfront_adapty](https://pub.dev/packages/pingfront_adapty).

## Learn more

- [Flutter quickstart](https://pingfront.sh/docs/flutter): setup, offers, saved links, push and the self-check.
- [The full guide](https://github.com/pingfront/pingfront-flutter#readme): the API next to the native SDKs, the
  embedded chat, your own chat UI, links into the chat and the parity notes.
