# Example

Configure RevenueCat first (or right after), then pass the adapter to `PingFront.configure`.

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_revenuecat/pingfront_revenuecat.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [PingFrontRevenueCat.module()]),
);
```
