# Example

Configure Superwall first (or right after), then pass the adapter to `PingFront.configure`.

```dart
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_superwall/pingfront_superwall.dart';

await PingFront.configure(
  'pk_live_…',
  options: PingFrontOptions(modules: [
    PingFrontSuperwall.module(placements: const [
      SuperwallPlacement('winback_offer', title: 'Come back for 50% off', kind: OfferKind.winback),
    ]),
  ]),
);
```
