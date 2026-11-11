import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_adapty/pingfront_adapty.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';

void main() {
  group('Adapty', () {
    test('encodes placements and every option', () {
      final module = PingFrontAdapty.module(
        placements: ['winback', 'settings_paywall'],
        identity: AdaptyIdentity.customerUserId,
        observerMode: true,
        presentsPaywalls: false,
        reportsEntitlement: false,
      ) as AdapterModule;
      expect(module.id, 'adapty');
      expect(module.options, {
        'placements': ['winback', 'settings_paywall'],
        'identity': 'customerUserId',
        'observerMode': true,
        'presentsPaywalls': false,
        'reportsEntitlement': false,
      });
    });

    test('defaults: the app identifies Adapty, the adapter buys', () {
      final module = PingFrontAdapty.module(placements: ['p']) as AdapterModule;
      expect(module.options['identity'], 'appManaged');
      expect(module.options['observerMode'], false);
    });
  });
}
