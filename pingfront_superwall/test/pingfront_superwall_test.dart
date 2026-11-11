import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_superwall/pingfront_superwall.dart';

void main() {
  group('Superwall', () {
    test('encodes placements, identity and entitlement reporting', () {
      final module = PingFrontSuperwall.module(
        placements: [
          const SuperwallPlacement(
            'winback_offer',
            title: 'Come back for 50% off',
            kind: OfferKind.winback,
            products: [
              OfferProduct(id: 'pro_yearly', price: '€29.99', period: 'P1Y'),
            ],
            params: {'source': 'chat'},
          ),
        ],
        identity: SuperwallIdentity.storeAccountToken,
        reportsEntitlement: false,
      ) as AdapterModule;
      expect(module.id, 'superwall');
      expect(module.options, {
        'placements': [
          {
            'placement': 'winback_offer',
            'title': 'Come back for 50% off',
            'kind': 'winback',
            'products': [
              {
                'id': 'pro_yearly',
                'price': '€29.99',
                'period': 'P1Y',
                'trial': null,
              },
            ],
            'params': {'source': 'chat'},
          },
        ],
        'identity': 'storeAccountToken',
        'reportsEntitlement': false,
      });
    });
  });
}
