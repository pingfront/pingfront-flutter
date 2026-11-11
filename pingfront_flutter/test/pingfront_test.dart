import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_flutter/src/messages.g.dart';

import 'support.dart';

void main() {
  late MockHostApi host;
  late FakePlatform platform;

  setUpAll(registerFallbacks);

  setUp(() {
    host = MockHostApi();
    platform = FakePlatform(host);
    PingFront.platform = platform;
    when(() => host.configure(any())).thenAnswer((_) async {});
    when(() => host.setHandlers(any(), any(), any())).thenAnswer((_) async {});
  });

  tearDown(() => platform.close());

  group('configure', () {
    test('sends the key and every option, encoded for native', () async {
      await PingFront.configure(
        'pk_test_abcdefghijklmnopqrstuvvd',
        options: const PingFrontOptions(
          baseUrl: 'http://localhost:8797/v1',
          logLevel: PingFrontLogLevel.debug,
          presentsChatForMoments: false,
          topics: [
            ChatTopic.billing,
            ChatTopic('sync', label: 'Sync stopped', prefill: 'Sync stopped '),
          ],
          appearance: ChatAppearance(
            accent: PingFrontColor(Color(0xFF3550E6), Color(0xFF7D91FF)),
            corners: ChatCorners.soft,
            headerStyle: ChatHeaderStyle.team,
            replyExpectation: 'Usually replies within a few hours',
            allowsPhotos: false,
          ),
          modules: [
            PingFrontModule.push(),
            PingFrontModule.reports(shakeToReport: false),
            PingFrontModule.store(products: ['pro_yearly']),
          ],
        ),
      );
      final request =
          verify(() => host.configure(captureAny())).captured.single
              as ConfigureRequest;
      expect(request.appKey, 'pk_test_abcdefghijklmnopqrstuvvd');
      expect(request.baseUrl, 'http://localhost:8797/v1');
      expect(request.logLevel, 'debug');
      expect(request.presentsChatForMoments, isFalse);
      expect(request.closesChatForOffers, isTrue);
      expect(request.handlesOffers, isFalse);
      expect(request.handlesLinks, isFalse);
      expect(request.topics!.map((t) => t.id), ['billing', 'sync']);
      expect(request.topics![0].symbol, 'billing');
      expect(request.topics![1].label, 'Sync stopped');
      expect(request.topics![1].prefill, 'Sync stopped ');
      expect(request.appearance.accent!.light, '#3550E6');
      expect(request.appearance.accent!.dark, '#7D91FF');
      expect(request.appearance.corners, 'soft');
      expect(request.appearance.headerStyle, 'team');
      expect(request.appearance.allowsPhotos, isFalse);
      expect(request.appearance.font, isNull);
      expect(request.modules.map((m) => m.id), ['push', 'reports', 'store']);
      expect(request.modules[1].shakeToReport, isFalse);
      expect(request.modules[1].logTail, isTrue);
      expect(request.modules[2].products, ['pro_yearly']);
    });

    test('reports the Dart handlers that are set', () async {
      PingFront.onOffer = (_) {};
      PingFront.onLink = (_) => false;
      await PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd');
      final request =
          verify(() => host.configure(captureAny())).captured.single
              as ConfigureRequest;
      expect(request.handlesOffers, isTrue);
      expect(request.handlesLinks, isTrue);
    });

    test('null reads the key natively (Info.plist or the manifest)', () async {
      await PingFront.configure(null);
      final request =
          verify(() => host.configure(captureAny())).captured.single
              as ConfigureRequest;
      expect(request.appKey, isNull);
    });

    test('turns native errors into PingFrontException', () async {
      when(() => host.configure(any())).thenThrow(
        PlatformException(
          code: 'invalid_input',
          message: 'baseUrl is not a URL',
        ),
      );
      await expectLater(
        PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd'),
        throwsA(
          isA<PingFrontException>()
              .having((e) => e.code, 'code', 'invalid_input')
              .having((e) => e.message, 'message', 'baseUrl is not a URL'),
        ),
      );
    });
  });

  group('calls', () {
    test('exportMyData returns the JSON text from native', () async {
      when(() => host.exportMyData())
          .thenAnswer((_) async => '{"person":{"id":"per_1"}}');
      expect(await PingFront.exportMyData(), '{"person":{"id":"per_1"}}');
      verify(() => host.exportMyData()).called(1);
    });

    test('exportMyData turns native errors into PingFrontException', () async {
      when(() => host.exportMyData()).thenThrow(
        PlatformException(code: 'session', message: 'Not signed in.'),
      );
      await expectLater(
        PingFront.exportMyData(),
        throwsA(isA<PingFrontException>()),
      );
    });

    test('identity, traits and logout go straight to native', () async {
      when(() => host.identify(any(), any(), any())).thenAnswer((_) async {});
      when(() => host.identifyWithToken(any())).thenAnswer((_) async {});
      when(() => host.setTraits(any())).thenAnswer((_) async {});
      when(() => host.logout()).thenAnswer((_) async {});
      await PingFront.identify(
        userId: 'u_1',
        name: 'Riley',
        email: 'r@example.com',
      );
      await PingFront.identifyWithToken('jwt');
      await PingFront.setTraits({'plan': 'pro'});
      await PingFront.logout();
      verifyInOrder([
        () => host.identify('u_1', 'Riley', 'r@example.com'),
        () => host.identifyWithToken('jwt'),
        () => host.setTraits({'plan': 'pro'}),
        () => host.logout(),
      ]);
    });

    test('entitlements travel as UTC milliseconds', () async {
      when(() => host.setEntitlement(any())).thenAnswer((_) async {});
      await PingFront.setEntitlement(
        Entitlement(
          state: EntitlementState.billingRetry,
          productId: 'pro_yearly',
          renewsAt: DateTime.utc(2026, 11, 14),
        ),
      );
      final sent =
          verify(() => host.setEntitlement(captureAny())).captured.single
              as EntitlementMessage;
      expect(sent.state, 'billingRetry');
      expect(sent.productId, 'pro_yearly');
      expect(
        sent.renewsAtMs,
        DateTime.utc(2026, 11, 14).millisecondsSinceEpoch,
      );
      expect(sent.source, 'app');
    });

    test('offer slots are encoded with their products', () async {
      when(() => host.setOffers(any())).thenAnswer((_) async {});
      await PingFront.setOffers(const [
        OfferSlot(
          id: 'pro_yearly',
          title: 'Pro yearly',
          kind: OfferKind.winback,
          products: [OfferProduct(id: 'pro', price: '€29.99', period: 'P1Y')],
        ),
      ]);
      final slots =
          verify(() => host.setOffers(captureAny())).captured.single
              as List<OfferSlotMessage>;
      expect(slots.single.kind, 'winback');
      expect(slots.single.available, isTrue);
      expect(slots.single.products.single.price, '€29.99');
    });

    test('openChat passes the topic; closeChat waits for native', () async {
      when(() => host.openChat(any())).thenAnswer((_) async {});
      final closed = Completer<void>();
      when(() => host.closeChat()).thenAnswer((_) => closed.future);
      await PingFront.openChat(topic: ChatTopic.bug);
      final topic =
          verify(() => host.openChat(captureAny())).captured.single
              as TopicMessage;
      expect(topic.id, 'bug');
      var done = false;
      unawaited(PingFront.closeChat().then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(
        done,
        isFalse,
        reason: 'closeChat completes once native says the chat is gone',
      );
      closed.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test(
      'a push payload whose pingfront value is JSON text is decoded',
      () async {
        when(() => host.handlePush(any(), any())).thenAnswer((_) async => true);
        final handled = await PingFront.handlePush({
          'pingfront': '{"v":1,"kind":"message","appId":"app_1"}',
        }, opened: false);
        expect(handled, isTrue);
        final captured =
            verify(() => host.handlePush(captureAny(), false)).captured.single
                as Map<String, Object?>;
        expect(captured['pingfront'], {
          'v': 1,
          'kind': 'message',
          'appId': 'app_1',
        });
      },
    );

    test('state decodes, with unknown levels kept as unknown', () async {
      when(() => host.state()).thenAnswer(
        (_) async => StateMessage(
          isConfigured: true,
          unreadCount: 2,
          isChatVisible: false,
          isTestDevice: false,
          person: PersonMessage(id: 'per_1', level: 'superuser'),
          configurationProblem: ProblemMessage(
            kind: 'invalidKey',
            message: 'The key has a typo.',
            disablesSdk: true,
          ),
        ),
      );
      final state = await PingFront.state();
      expect(state.unreadCount, 2);
      expect(state.person!.level, PersonLevel.unknown);
      expect(
        state.configurationProblem!.kind,
        ConfigurationProblemKind.invalidKey,
      );
    });
  });

  group('moment', () {
    test('rejects values native cannot send', () {
      expect(
        () => PingFront.moment('paywall_closed', {'when': DateTime(2026)}),
        throwsArgumentError,
      );
      verifyNever(() => host.moment(any(), any()));
    });

    test('decodes every result, unknown ones included', () async {
      final results = <String, Matcher>{
        'notListened': isA<MomentNotListened>(),
        'ignored': isA<MomentIgnored>(),
        'scheduled': isA<MomentScheduled>(),
        'delivered': isA<MomentDelivered>(),
        'heldOut': isA<MomentHeldOut>(),
        'invalidName': isA<MomentInvalidName>(),
        'brandNew': isA<MomentUnknown>().having(
          (r) => r.kind,
          'kind',
          'brandNew',
        ),
      };
      for (final MapEntry(:key, :value) in results.entries) {
        when(() => host.moment(any(), any()))
            .thenAnswer((_) async => MomentResultMessage(kind: key));
        expect(await PingFront.moment('paywall_closed'), value);
      }
      when(() => host.moment(any(), any())).thenAnswer(
        (_) async =>
            MomentResultMessage(kind: 'openRequested', presented: true),
      );
      expect(
        await PingFront.moment('trial_cancelled', {'seconds': 42, 'pro': true}),
        isA<MomentOpenRequested>().having(
          (r) => r.presented,
          'presented',
          true,
        ),
      );
      verify(() => host.moment('trial_cancelled', {'seconds': 42, 'pro': true}))
          .called(1);
      when(() => host.moment(any(), any())).thenAnswer(
        (_) async => MomentResultMessage(
          kind: 'failed',
          errorCode: 'network',
          errorMessage: 'offline',
        ),
      );
      expect(
        await PingFront.moment('paywall_closed'),
        isA<MomentFailed>().having((r) => r.error.code, 'code', 'network'),
      );
    });
  });

  group('events', () {
    test('known events decode to their types', () async {
      final received = <PingFrontEvent>[];
      final sub = PingFront.events.listen(received.add);
      platform.events$
        ..add(EventMessage(type: 'chatOpened', data: {}))
        ..add(EventMessage(type: 'unreadChanged', data: {'count': 3}))
        ..add(
          EventMessage(
            type: 'messageReceived',
            data: {
              'id': 'msg_1',
              'authorName': 'Deniz',
              'preview': 'Hi Riley',
              'isPing': true,
              'isAi': false,
            },
          ),
        )
        ..add(
          EventMessage(
            type: 'offerRequested',
            data: {
              'request': {
                'offerId': 'pro_yearly',
                'cardId': 'card_1',
                'messageId': 'msg_2',
                'storeOffer': {'kind': 'promotional', 'id': 'winback50'},
              },
            },
          ),
        )
        ..add(
          EventMessage(
            type: 'offerCompleted',
            data: {
              'request': {
                'offerId': 'pro_yearly',
                'cardId': 'card_1',
                'messageId': 'msg_2',
              },
              'outcome': 'failed',
              'failure': 'network',
            },
          ),
        )
        ..add(
          EventMessage(
            type: 'configurationProblem',
            data: {
              'kind': 'invalidKey',
              'message': 'The key has a typo.',
              'disablesSdk': true,
            },
          ),
        );
      await pumpEventQueue();
      await sub.cancel();
      expect(received[0], isA<ChatOpened>());
      expect(
        received[1],
        isA<UnreadChanged>().having((e) => e.count, 'count', 3),
      );
      expect(
        received[2],
        isA<MessageReceived>()
            .having((e) => e.message.authorName, 'author', 'Deniz')
            .having((e) => e.message.isPing, 'isPing', true),
      );
      expect(
        received[3],
        isA<OfferRequested>()
            .having((e) => e.request.offerId, 'offerId', 'pro_yearly')
            .having(
              (e) => e.request.storeOffer!.kind,
              'store kind',
              'promotional',
            ),
      );
      expect(
        received[4],
        isA<OfferCompleted>()
            .having((e) => e.outcome, 'outcome', 'failed')
            .having((e) => e.failure, 'failure', 'network'),
      );
      expect(
        received[5],
        isA<ConfigurationProblemFound>().having(
          (e) => e.problem.kind,
          'kind',
          ConfigurationProblemKind.invalidKey,
        ),
      );
    });

    test(
      'unknown and malformed events pass through as PingFrontEvent.unknown',
      () async {
        final received = <PingFrontEvent>[];
        final sub = PingFront.events.listen(received.add);
        platform.events$
          ..add(EventMessage(type: 'surveyAnswered', data: {'score': 9}))
          ..add(EventMessage(type: 'unreadChanged', data: {'count': 'three'}));
        await pumpEventQueue();
        await sub.cancel();
        expect(
          received[0],
          isA<PingFrontUnknownEvent>()
              .having((e) => e.type, 'type', 'surveyAnswered')
              .having((e) => e.data, 'data', {'score': 9}),
        );
        expect(
          received[1],
          isA<PingFrontUnknownEvent>().having(
            (e) => e.type,
            'type',
            'unreadChanged',
          ),
        );
      },
    );
  });

  group('unread count', () {
    test('the stream starts with the current value, then changes', () async {
      final notifier = PingFront.unread;
      platform.unread$.add(2);
      await pumpEventQueue();
      expect(notifier.value, 2);

      final values = <int>[];
      final sub = PingFront.unreadCount.listen(values.add);
      await pumpEventQueue();
      platform.unread$
        ..add(2)
        ..add(5)
        ..add(0);
      await pumpEventQueue();
      await sub.cancel();
      expect(values, [2, 5, 0], reason: 'current value first, repeats dropped');
    });

    test('the ValueListenable notifies listeners', () async {
      final seen = <int>[];
      final notifier = PingFront.unread..addListener(() {});
      notifier.addListener(() => seen.add(notifier.value));
      platform.unread$
        ..add(1)
        ..add(4);
      await pumpEventQueue();
      expect(seen, [1, 4]);
    });
  });

  group('offers and links', () {
    test(
      'setting onOffer tells native, keeping the close-the-chat policy',
      () async {
        await PingFront.configure(
          'pk_test_abcdefghijklmnopqrstuvvd',
          options: const PingFrontOptions(closesChatForOffers: false),
        );
        PingFront.onOffer = (_) {};
        await pumpEventQueue();
        verify(() => host.setHandlers(true, false, false)).called(1);
        PingFront.onOffer = null;
        await pumpEventQueue();
        verify(() => host.setHandlers(false, false, false)).called(1);
      },
    );

    test('closing the chat for offers is the default', () {
      expect(const PingFrontOptions().closesChatForOffers, isTrue);
    });

    test('an offer tap from native reaches onOffer, decoded', () async {
      final requests = <OfferRequest>[];
      PingFront.onOffer = requests.add;
      await platform.flutterApi!.onOffer(
        OfferRequestMessage(
          offerId: 'pro_yearly',
          cardId: 'card_1',
          messageId: 'msg_1',
          slot: OfferSlotMessage(
            id: 'pro_yearly',
            title: 'Pro yearly',
            kind: 'discount',
            available: true,
            products: [],
            source: 'app',
          ),
          storeOffer: StoreOfferMessage(
            kind: 'intro',
            id: 'trial7',
            basePlanId: 'yearly',
          ),
        ),
      );
      expect(requests.single.offerId, 'pro_yearly');
      expect(requests.single.slot!.kind, OfferKind.discount);
      expect(requests.single.storeOffer!.basePlanId, 'yearly');
    });

    test('onOffer can be async; native waits for it', () async {
      final shown = Completer<void>();
      var finished = false;
      PingFront.onOffer = (_) async {
        await shown.future;
        finished = true;
      };
      final call = platform.flutterApi!.onOffer(
        OfferRequestMessage(offerId: 'o', cardId: 'c', messageId: 'm'),
      );
      await pumpEventQueue();
      expect(finished, isFalse);
      shown.complete();
      await call;
      expect(finished, isTrue);
    });

    test('a link tap asks onLink; no handler means not handled', () async {
      PingFront.onLink = (_) => true;
      PingFront.onLink = null;
      expect(await platform.flutterApi!.onLink('clockwise://alarms'), isFalse);
      final uris = <Uri>[];
      PingFront.onLink = (uri) {
        uris.add(uri);
        return uri.scheme == 'clockwise';
      };
      expect(await platform.flutterApi!.onLink('clockwise://alarms'), isTrue);
      expect(await platform.flutterApi!.onLink('https://example.com'), isFalse);
      expect(uris.map((u) => u.scheme), ['clockwise', 'https']);
    });
  });

  group('chat links', () {
    test('before configure: forwarded as is, native keeps it', () async {
      when(() => host.handleUrl(any())).thenAnswer((_) async => true);
      const link = 'myapp://support?pingfront=chat&topic=billing';
      expect(await PingFront.handleUrl(link), isTrue);
      expect(verify(() => host.handleUrl(captureAny())).captured, [link]);
      verifyNever(() => host.configure(any()));
    });

    test('after configure: returns native\'s answer for each URL', () async {
      when(() => host.handleUrl('https://example.com/help?pingfront=chat'))
          .thenAnswer((_) async => true);
      when(() => host.handleUrl('https://example.com/?pingfront=open'))
          .thenAnswer((_) async => false);
      await PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd');
      expect(
        await PingFront.handleUrl('https://example.com/help?pingfront=chat'),
        isTrue,
      );
      expect(
        await PingFront.handleUrl('https://example.com/?pingfront=open'),
        isFalse,
      );
    });

    test('hostile and huge strings go to native unchanged', () async {
      when(() => host.handleUrl(any())).thenAnswer((_) async => false);
      final huge = 'https://example.com/?pingfront=chat&pad=${'a' * 5000}';
      const hostile = 'javascript:alert(1)//?pingfront=chat';
      expect(await PingFront.handleUrl(huge), isFalse);
      expect(await PingFront.handleUrl(hostile), isFalse);
      expect(await PingFront.handleUrl(''), isFalse);
      expect(verify(() => host.handleUrl(captureAny())).captured, [
        huge,
        hostile,
        '',
      ]);
    });
  });

  group('self-check', () {
    test('returns the native result: passed, code and line', () async {
      when(() => host.selfCheck()).thenAnswer(
        (_) async => SelfCheckMessage(
          passed: true,
          code: 'ignored when passed',
          line: '${Brand.selfCheckPrefix} PASS',
        ),
      );
      expect(
        await PingFront.selfCheck(),
        const SelfCheckResult(passed: true, line: 'PingFront self-check: PASS'),
      );
      verify(() => host.selfCheck()).called(1);
    });

    test(
      'a failure carries its code, unexpected when the native side has none',
      () async {
        const line = 'PingFront self-check: FAIL key_unknown: Check the key.';
        when(() => host.selfCheck()).thenAnswer(
          (_) async =>
              SelfCheckMessage(passed: false, code: 'key_unknown', line: line),
        );
        final result = await PingFront.selfCheck();
        expect(result.passed, isFalse);
        expect(result.code, 'key_unknown');
        expect(result.line, line);
        when(
          () => host.selfCheck(),
        ).thenAnswer((_) async => SelfCheckMessage(passed: false, line: 'x'));
        expect((await PingFront.selfCheck()).code, 'unexpected');
      },
    );
  });

  group('colors', () {
    test('hex parsing and output', () {
      final color = PingFrontColor.hex('#3550e6', '7D91FF')!;
      expect(PingFrontColor.toHex(color.light), '#3550E6');
      expect(PingFrontColor.toHex(color.dark), '#7D91FF');
      expect(PingFrontColor.hex('blue'), isNull);
      expect(color, PingFrontColor.hex('#3550E6', '#7D91FF'));
    });
  });
}
