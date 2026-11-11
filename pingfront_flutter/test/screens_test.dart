import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_flutter/src/messages.g.dart';
import 'package:pingfront_flutter/src/thread.dart' show decodeCardJson;

import 'support.dart';

/// Saved links (https://pingfront.sh/docs/offers#saved-links): registering screens and opening them from link cards.
void main() {
  late MockHostApi host;
  late FakePlatform platform;

  setUpAll(() {
    registerFallbacks();
    registerFallbackValue(<AppScreenMessage>[]);
  });

  setUp(() {
    host = MockHostApi();
    platform = FakePlatform(host);
    PingFront.platform = platform;
    when(() => host.registerScreens(any())).thenAnswer((_) async {});
    when(() => host.setScreenHandler(any())).thenAnswer((_) async {});
  });

  tearDown(() => platform.close());

  test('registerScreens passes the list on', () async {
    await PingFront.registerScreens(const [
      AppScreen('settings.sound', title: 'Sound settings'),
      AppScreen('plans/yearly'),
    ]);
    final sent =
        verify(() => host.registerScreens(captureAny())).captured.single
            as List<AppScreenMessage>;
    expect(sent.map((s) => (s.id, s.title)), [
      ('settings.sound', 'Sound settings'),
      ('plans/yearly', null),
    ]);
  });

  test('a bad id throws in a debug build and sends nothing', () {
    expect(
      () => PingFront.registerScreens(const [AppScreen('not ok')]),
      throwsArgumentError,
    );
    verifyNever(() => host.registerScreens(any()));
  });

  test(
    'onScreen turns the native handler on and off and answers taps',
    () async {
      PingFront.onScreen = (_) => true;
      verify(() => host.setScreenHandler(true)).called(1);
      final seen = <LinkScreen>[];
      PingFront.onScreen = (screen) async {
        seen.add(screen);
        return screen.id == 'plans/yearly';
      };
      final message = LinkScreenMessage(
        id: 'plans/yearly',
        params: {'tab': 'yearly'},
      );
      expect(await platform.flutterApi!.onScreen(message), isTrue);
      expect(seen, [
        const LinkScreen(id: 'plans/yearly', params: {'tab': 'yearly'}),
      ]);
      expect(
        await platform.flutterApi!.onScreen(
          LinkScreenMessage(id: 'other', params: {}),
        ),
        isFalse,
      );
      PingFront.onScreen = (_) => throw StateError('app bug');
      expect(await platform.flutterApi!.onScreen(message), isFalse);
      PingFront.onScreen = null;
      verify(() => host.setScreenHandler(false)).called(1);
      expect(await platform.flutterApi!.onScreen(message), isFalse);
    },
  );

  test(
    'a link card decodes screen and savedLinkId; a bad screen is dropped',
    () {
      final card = decodeCardJson({
        'kind': 'link',
        'id': 'l1',
        'title': 'Plans',
        'url': '',
        'button': 'Open',
        'savedLinkId': 'sl_1',
        'screen': {
          'id': 'plans/yearly',
          'params': {'tab': 'yearly', 'n': 3},
        },
      }) as LinkCard;
      expect(
        card.screen,
        const LinkScreen(id: 'plans/yearly', params: {'tab': 'yearly'}),
      );
      expect(card.savedLinkId, 'sl_1');
      final bad = decodeCardJson({
        'kind': 'link',
        'id': 'l2',
        'title': 'Docs',
        'url': 'https://example.com',
        'button': 'Open',
        'screen': 'nope',
      }) as LinkCard;
      expect(bad.screen, isNull);
      expect(bad.url, 'https://example.com');
    },
  );
}
