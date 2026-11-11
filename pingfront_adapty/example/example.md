# Example

Configure Adapty first (or right after), then pass the adapter to `PingFront.configure`.

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_adapty/pingfront_adapty.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [
    PingFrontAdapty.module(placements: ['winback', 'settings_paywall']),
  ]),
);
```
