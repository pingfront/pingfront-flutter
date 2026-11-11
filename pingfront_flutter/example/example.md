# Example

Configure once before `runApp`, then open the chat from a Help row that shows the unread count.

```dart
import 'package:flutter/material.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PingFront.configure('pk_live_…');
  runApp(const MaterialApp(home: HelpPage()));
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help')),
    body: ValueListenableBuilder<int>(
      valueListenable: PingFront.unread,
      builder: (context, unread, _) => ListTile(
        title: const Text('Talk to us'),
        trailing: unread > 0 ? Badge(label: Text('$unread')) : null,
        onTap: () => PingFront.openChat(),
      ),
    ),
  );
}
```

Clockwise, a small app that uses the plugin the way an app would (offer cards that open a Flutter paywall, the
embedded chat in a Help tab, deep links), is in the
[repository's example folder](https://github.com/pingfront/pingfront-flutter/tree/main/example).
