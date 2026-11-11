import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_revenuecat/pingfront_revenuecat.dart';

void main() {
  group('RevenueCat', () {
    test('encodes the options for the native factory', () {
      final module = PingFrontRevenueCat.module(
        offerings: ['winter_sale', 'default'],
        presentsPaywalls: false,
      ) as AdapterModule;
      expect(module.id, 'revenuecat');
      expect(module.options, {
        'offerings': ['winter_sale', 'default'],
        'presentsPaywalls': false,
      });
    });

    test('defaults: every offering, paywalls presented', () {
      final module = PingFrontRevenueCat.module() as AdapterModule;
      expect(module.options, {'offerings': null, 'presentsPaywalls': true});
    });
  });
}
