import 'dart:async';
// The APIs added for parity with the native SDKs: language, log lines, the two new events, push
// permission, background pushes, the store account token, the look, team actions, the conversation
// (decoded with the protocol fixtures) and the embedded chat view.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_flutter/src/conversation.dart';
import 'package:pingfront_flutter/src/messages.g.dart';
import 'package:pingfront_flutter/src/thread.dart';

import 'support.dart';

/// The `valid` values of a schema fixture in [fixturesPath].
List<Object?> fixtureValues(String path) {
  final file = File('$fixturesPath/$path');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return [
    for (final c in json['valid']! as List<Object?>)
      (c! as Map<String, Object?>)['value'],
  ];
}

ColorMessage color(String hex) => ColorMessage(light: hex, dark: hex);

LookMessage lookMessage({String scheme = 'dark', String font = 'serif'}) =>
    LookMessage(
      appName: 'Clockwise',
      accent: ColorMessage(light: '#3550E6', dark: '#7D91FF'),
      onAccent: color('#FFFFFF'),
      background: color('#FFFFFF'),
      teamBubble: color('#E9E9EB'),
      text: color('#000000'),
      muted: color('#8E8E93'),
      scheme: scheme,
      font: font,
      corners: 'soft',
      density: 'compact',
      headerStyle: 'team',
      headerTitle: {'default': 'Clockwise team', 'de': 'Clockwise-Team'},
      showsLocalTime: true,
      showsReplyExpectation: false,
      showsWelcomeFaces: true,
      topics: [
        LookTopicMessage(
          id: 'alarms',
          label: {'default': 'Alarms', 'de': 'Wecker'},
          symbol: 'question',
          prefill: {'default': 'My alarm '},
        ),
        LookTopicMessage(id: 'x', symbol: 'a_symbol_from_the_future'),
      ],
      allowsPhotos: true,
      allowsReports: false,
      showsNames: true,
      showsAvatars: false,
      timestamps: 'always',
      aiName: 'Assistant',
      teamJson: '[{"id":"mem_1","name":"Deniz","timeZone":"Europe/Istanbul"},{"name":"no id"}]',
      isDraft: true,
      revision: 7,
      bubbleRadius: 12,
    );

ConversationMessage conversationMessage({
  required String messagesJson,
  List<PendingMessageMessage> pending = const [],
  List<TimelineItemMessage> timeline = const [],
}) => ConversationMessage(
  phase: 'ready',
  messagesJson: messagesJson,
  pending: pending,
  timeline: timeline,
  hasOlder: true,
  isLoadingOlder: false,
  teamJson: '[]',
  canSend: false,
  closedReason: 'verification_required',
  status: 'resolved',
  typingIsAi: true,
  typingName: 'Assistant',
  live: 'waiting',
  liveRetryInMs: 1500,
  liveOffline: true,
  teamReadSeq: 4,
  isOffline: true,
  isServerUnreachable: true,
  draft: 'half a thought',
  composerInsertion: 'My alarm ',
  coolingDown: ['messages'],
  awaitingApproval: ['card_1'],
);

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

  ConfigureRequest configured() =>
      verify(() => host.configure(captureAny())).captured.single
          as ConfigureRequest;

  group('configure', () {
    test(
      'sends the language, the push environment and log forwarding',
      () async {
        await PingFront.configure(
          'pk_test_abcdefghijklmnopqrstuvvd',
          options: PingFrontOptions(
            language: 'pt-BR',
            pushEnvironment: PushEnvironment.production,
            logHandler: (_) {},
          ),
        );
        final request = configured();
        expect(request.language, 'pt-BR');
        expect(request.pushEnvironment, 'production');
        expect(request.forwardsLogs, isTrue);
      },
    );

    test('forwards no logs and keeps the system language by default', () async {
      await PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd');
      final request = configured();
      expect(request.language, isNull);
      expect(request.pushEnvironment, isNull);
      expect(request.forwardsLogs, isFalse);
    });

    test('an adapter module travels with its id and options', () async {
      await PingFront.configure(
        'pk_test_abcdefghijklmnopqrstuvvd',
        options: const PingFrontOptions(
          modules: [
            AdapterModule('revenuecat', {
              'offerings': ['default'],
              'presentsPaywalls': false,
            }),
          ],
        ),
      );
      final module = configured().modules.single;
      expect(module.id, 'revenuecat');
      expect(module.options, {
        'offerings': ['default'],
        'presentsPaywalls': false,
      });
    });
  });

  group('log lines', () {
    test('reach the handler decoded; an unknown level reads as info', () async {
      final lines = <PingFrontLogEntry>[];
      await PingFront.configure(
        'pk_test_abcdefghijklmnopqrstuvvd',
        options: PingFrontOptions(logHandler: lines.add),
      );
      platform.flutterApi!.onLog(
        LogEntryMessage(
          level: 'debug',
          message: 'GET /v1/me 200',
          category: 'network',
        ),
      );
      platform.flutterApi!.onLog(
        LogEntryMessage(level: 'chatty', message: 'Session <private> ready'),
      );
      expect(lines.map((l) => l.level), [
        PingFrontLogLevel.debug,
        PingFrontLogLevel.info,
      ]);
      expect(lines.first.category, 'network');
      expect(lines.first.message, 'GET /v1/me 200');
      expect(lines.last.category, isNull);
      expect(
        lines.first.toString(),
        '[pingfront/network] debug: GET /v1/me 200',
      );
    });

    test('a later configure without a handler stops them', () async {
      final lines = <PingFrontLogEntry>[];
      await PingFront.configure(
        'pk_test_abcdefghijklmnopqrstuvvd',
        options: PingFrontOptions(logHandler: lines.add),
      );
      await PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd');
      platform.flutterApi!.onLog(LogEntryMessage(level: 'info', message: 'x'));
      expect(lines, isEmpty);
    });
  });

  group('calls', () {
    test('language: set and read', () async {
      when(() => host.setLanguage(any())).thenAnswer((_) async {});
      when(() => host.language()).thenAnswer((_) async => 'de');
      await PingFront.setLanguage('de');
      await PingFront.setLanguage(null);
      expect(await PingFront.language(), 'de');
      verifyInOrder([
        () => host.setLanguage('de'),
        () => host.setLanguage(null),
      ]);
    });

    test('store account token, app badge and push permission', () async {
      when(() => host.storeAccountToken())
          .thenAnswer((_) async => '3F2504E0-4F89-41D3-9A0C-0305E82C3301');
      when(() => host.usesAppBadge()).thenAnswer((_) async => true);
      when(() => host.requestPushAuthorization())
          .thenAnswer((_) async => false);
      expect(
        await PingFront.storeAccountToken(),
        '3F2504E0-4F89-41D3-9A0C-0305E82C3301',
      );
      expect(await PingFront.usesAppBadge(), isTrue);
      expect(await PingFront.requestPushAuthorization(), isFalse);
    });

    test(
      'the app badge is the native answer on Android too, never forced off',
      () async {
        for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
          debugDefaultTargetPlatformOverride = platform;
          for (final answer in [true, false]) {
            when(() => host.usesAppBadge()).thenAnswer((_) async => answer);
            expect(await PingFront.usesAppBadge(), answer, reason: '$platform');
          }
        }
        debugDefaultTargetPlatformOverride = null;
      },
    );

    test(
      'a background push: every native answer, unknown ones as noData',
      () async {
        final answers = ['newData', 'noData', 'failed', 'later', null];
        var i = 0;
        when(() => host.handleBackgroundPush(any()))
            .thenAnswer((_) async => answers[i++]);
        final results = [
          for (final _ in answers)
            await PingFront.handleBackgroundPush({'aps': {}}),
        ];
        expect(results, [
          BackgroundPushResult.newData,
          BackgroundPushResult.noData,
          BackgroundPushResult.failed,
          BackgroundPushResult.noData,
          null,
        ]);
      },
    );

    test(
      'a background push: a pingfront value sent as JSON text is decoded',
      () async {
        when(() => host.handleBackgroundPush(any()))
            .thenAnswer((_) async => 'noData');
        await PingFront.handleBackgroundPush({
          'pingfront': '{"v":1,"kind":"config"}',
        });
        final payload =
            verify(() => host.handleBackgroundPush(captureAny()))
                    .captured
                    .single
                as Map<String, Object?>;
        expect(payload['pingfront'], {'v': 1, 'kind': 'config'});
      },
    );

    test('native errors become PingFrontException', () async {
      when(() => host.storeAccountToken()).thenThrow(
        PlatformException(code: 'not_configured', message: 'Configure first.'),
      );
      await expectLater(
        PingFront.storeAccountToken(),
        throwsA(
          isA<PingFrontException>().having(
            (e) => e.code,
            'code',
            'not_configured',
          ),
        ),
      );
    });
  });

  group('events', () {
    Future<List<PingFrontEvent>> decode(List<EventMessage> messages) async {
      final events = <PingFrontEvent>[];
      final sub = PingFront.events.listen(events.add);
      messages.forEach(platform.events$.add);
      await pumpEventQueue();
      await sub.cancel();
      return events;
    }

    test(
      'messageSent and cardOpened decode; an unknown card kind keeps its name',
      () async {
        final events = await decode([
          EventMessage(
            type: 'messageSent',
            data: {
              'id': 'msg_1',
              'textLength': 12,
              'photoCount': 2,
              'repliesToPing': true,
            },
          ),
          EventMessage(
            type: 'cardOpened',
            data: {
              'kind': 'store_action',
              'cardId': 'c1',
              'messageId': 'msg_2',
            },
          ),
          EventMessage(
            type: 'cardOpened',
            data: {'kind': 'poll', 'cardId': 'c2', 'messageId': 'msg_3'},
          ),
        ]);
        final sent = (events[0] as MessageSent).message;
        expect(sent.id, 'msg_1');
        expect(sent.textLength, 12);
        expect(sent.photoCount, 2);
        expect(sent.repliesToPing, isTrue);
        final opened = (events[1] as CardOpened).card;
        expect(opened.kind, CardKind.storeAction);
        expect(opened.cardId, 'c1');
        expect(opened.messageId, 'msg_2');
        final future = (events[2] as CardOpened).card;
        expect(future.kind, const CardKind('poll'));
        expect(future.kind.isKnown, isFalse);
      },
    );

    test('malformed ones arrive as unknown, never as errors', () async {
      final events = await decode([
        EventMessage(type: 'messageSent', data: {'textLength': 1}),
        EventMessage(type: 'cardOpened', data: {'kind': 'offer'}),
      ]);
      expect(events, everyElement(isA<PingFrontUnknownEvent>()));
      expect((events[1] as PingFrontUnknownEvent).data, {'kind': 'offer'});
    });
  });

  group('look', () {
    test('decodes colors, enums, texts, topics and the team', () async {
      when(() => host.look()).thenAnswer((_) async => lookMessage());
      final look = await PingFront.look();
      expect(look.appName, 'Clockwise');
      expect(look.accent, PingFrontColor.hex('#3550E6', '#7D91FF'));
      expect(look.scheme, ChatScheme.dark);
      expect(look.font, ChatFont.serif);
      expect(look.corners, ChatCorners.soft);
      expect(look.density, ChatDensity.compact);
      expect(look.headerStyle, ChatHeaderStyle.team);
      expect(look.timestamps, ChatTimestamps.always);
      expect(look.headerTitle!.resolve('de-AT'), 'Clockwise-Team');
      expect(look.headerTitle!.resolve('fr'), 'Clockwise team');
      expect(look.topics.map((t) => t.symbol), [
        TopicSymbol.question,
        TopicSymbol.other,
      ]);
      final topic = look.topics.first.toChatTopic('de');
      expect(topic.id, 'alarms');
      expect(topic.label, 'Wecker');
      expect(topic.prefill, 'My alarm ');
      // A malformed member is dropped.
      expect(look.team.map((m) => m.name), ['Deniz']);
      expect(look.team.single.timeZone, 'Europe/Istanbul');
      expect(look.isDraft, isTrue);
      expect(look.revision, 7);
      expect(look.bubbleRadius, 12);
    });

    test('unknown enum values fall back to the defaults', () async {
      when(() => host.look())
          .thenAnswer((_) async => lookMessage(scheme: 'sepia', font: 'mono'));
      final look = await PingFront.look();
      expect(look.scheme, ChatScheme.auto);
      expect(look.font, ChatFont.system);
    });

    test('the stream decodes every value', () async {
      final looks = <ResolvedLook>[];
      final sub = PingFront.looks.listen(looks.add);
      platform.looks$.add(lookMessage());
      await pumpEventQueue();
      await sub.cancel();
      expect(looks.single.aiName, 'Assistant');
    });
  });

  test('each native stream is shared: one channel listen, every Dart listener served', () {
    expect(identical(PingFront.looks, PingFront.looks), isTrue);
    expect(identical(PingFront.teamActions, PingFront.teamActions), isTrue);
    expect(
      identical(PingFront.conversation.states, PingFront.conversation.states),
      isTrue,
    );
  });

  group('team actions', () {
    test('decode, and complete or fail through native', () async {
      when(() => host.completeTeamAction(any())).thenAnswer((_) async {});
      when(() => host.failTeamAction(any(), any())).thenAnswer((_) async {});
      final actions = <TeamAction>[];
      final sub = PingFront.teamActions.listen(actions.add);
      platform.teamActions$
        ..add(
          TeamActionMessage(
            id: 'run_1',
            actionId: 'extend_trial',
            name: 'Extend trial',
            fields: {'reason': 'bug'},
            days: 7,
            untilMs: DateTime.utc(2026, 11, 14).millisecondsSinceEpoch,
            ackRequired: true,
            createdAtMs: DateTime.utc(2026, 11, 6).millisecondsSinceEpoch,
            expiresAtMs: DateTime.utc(2026, 11, 7).millisecondsSinceEpoch,
          ),
        )
        ..add(
          TeamActionMessage(
            id: 'run_2',
            actionId: 'repair_sync',
            name: 'Repair sync',
            fields: {},
            ackRequired: false,
            createdAtMs: 0,
            expiresAtMs: 0,
          ),
        );
      await pumpEventQueue();
      await sub.cancel();
      final first = actions.first;
      expect(first.actionId, 'extend_trial');
      expect(first.days, 7);
      expect(first.until, DateTime.utc(2026, 11, 14));
      expect(first.fields, {'reason': 'bug'});
      expect(first.ackRequired, isTrue);
      expect(first.expiresAt, DateTime.utc(2026, 11, 7));
      expect(actions.last.until, isNull);
      await first.complete();
      await actions.last.fail("This version can't do that.");
      verify(() => host.completeTeamAction('run_1')).called(1);
      verify(() => host.failTeamAction('run_2', "This version can't do that."))
          .called(1);
    });
  });

  group('conversation', () {
    test('every protocol fixture message decodes', () {
      final values = fixtureValues('sdk/Message.json');
      final messages = values.map(decodeMessageJson).toList();
      expect(messages, everyElement(isNotNull));
      final ping = messages[0]!;
      expect(ping.author.kind, AuthorKind.team);
      expect(ping.ping!.kind, PingKind.play);
      expect(ping.ping!.playId, 'play_1');
      expect(ping.plainText, 'Want a week more to decide?');
      final choices = (ping.parts[1] as CardPart).card as ChoicesCard;
      expect(choices.options.map((o) => o.label), ['Yes please', 'No thanks']);
      expect((ping.parts[2] as ReceiptPart).action.name, 'trial_extended');
      expect(
        (messages[1]!.parts.single as ReceiptPart).action,
        ReceiptAction.handedOff,
      );
      final image = messages[2]!.parts.single as ImagePart;
      expect(image.width, 390);
      expect(messages[2]!.fallback, '[Photo]');
      expect(messages[2]!.ping!.reasonCode, 'manual');
      final rated = messages[3]!.parts.single as CardPart;
      expect(rated.result!.rating, 4);
      expect((rated.card as RatingCard).scale, 5);
      final offer = (messages[4]!.parts.single as CardPart).card as OfferCard;
      expect(offer.offer!.kind, 'promotional');
      expect(offer.offer!.productId, 'pro.yearly');
      expect(messages[5]!.translation!.texts, [
        'Arreglado en 2.3.1, actualiza cuando puedas.',
      ]);
      expect(messages[5]!.translation!.from, 'en');
    });

    test('every protocol fixture thread decodes its messages and team', () {
      for (final value in fixtureValues('sdk/ThreadResponse.json')) {
        final thread = value! as Map<String, Object?>;
        expect(
          decodeMessagesJson(jsonEncode(thread['messages'])),
          hasLength((thread['messages']! as List<Object?>).length),
        );
        expect(
          decodeTeamJson(jsonEncode(thread['team'])),
          hasLength((thread['team']! as List<Object?>).length),
        );
      }
    });

    test(
      'unknown part types, card kinds and enum values decode to unknown cases',
      () {
        final message = decodeMessageJson({
          'id': 'm',
          'seq': 1,
          'author': {'kind': 'robot'},
          'createdAt': '2026-11-06T10:00:00Z',
          'parts': [
            {'type': 'poll', 'question': '?'},
            {
              'type': 'card',
              'card': {'kind': 'poll', 'id': 'c9'},
            },
            {
              'type': 'card',
              'card': {'kind': 'link', 'id': 'c10'},
            },
            {
              'type': 'card',
              'card': {
                'kind': 'review',
                'id': 'c11',
                'mode': 'hologram',
                'button': 'Rate',
              },
            },
            {
              'type': 'image',
              'attachmentId': 'a',
              'width': 1,
              'height': 1,
              'url': 'https://x',
              'removed': true,
            },
            {'type': 'text'},
          ],
          'ping': {'kind': 'telepathy', 'explanation': 'Why'},
        })!;
        expect(message.author.kind, AuthorKind.unknown);
        expect((message.parts[0] as UnknownPart).type, 'poll');
        final future = (message.parts[1] as CardPart).card as UnknownCard;
        expect(future.kind, const CardKind('poll'));
        expect(future.id, 'c9');
        // A known kind missing required fields is unknown too, never an error.
        expect((message.parts[2] as CardPart).card, isA<UnknownCard>());
        final review = (message.parts[3] as CardPart).card as ReviewCard;
        expect(review.mode, ReviewMode.unknown);
        final removed = message.parts[4] as ImagePart;
        expect(removed.removed, isTrue);
        expect(removed.url, isNull);
        expect(message.parts[5], isA<UnknownPart>());
        expect(message.ping!.kind, PingKind.unknown);
      },
    );

    test('a malformed message or array is dropped, never thrown', () {
      expect(decodeMessageJson({'id': 'm'}), isNull);
      expect(decodeMessagesJson('not json'), isEmpty);
      expect(decodeMessagesJson('{"a":1}'), isEmpty);
      expect(
        decodeMessagesJson(
          '[{"id":"m","seq":1,"author":{"kind":"team"},"parts":[],"createdAt":"2026-11-06T10:00:00Z"}, 7]',
        ),
        hasLength(1),
      );
    });

    test('a snapshot decodes, with the timeline joined to its messages', () {
      final messagesJson = jsonEncode([
        fixtureValues('sdk/Message.json').first,
      ]);
      final state = decodeConversation(
        conversationMessage(
          messagesJson: messagesJson,
          pending: [
            PendingMessageMessage(
              clientId: 'c-1',
              text: 'hi',
              photos: [
                PendingPhotoMessage(
                  width: 10,
                  height: 20,
                  bytes: 300,
                  sha256: 'ab',
                ),
              ],
              createdAtMs: 0,
              attempts: 2,
              state: 'failed',
              failure: 'Too large',
            ),
            PendingMessageMessage(
              clientId: 'c-2',
              text: 'still there?',
              photos: [],
              createdAtMs: 0,
              attempts: 1,
              state: 'failed',
              failure: 'Paused',
              heldFor: 'app_paused',
            ),
          ],
          timeline: [
            TimelineItemMessage(
              id: 'msg_1',
              contentKind: 'message',
              contentId: 'msg_1',
              side: 'team',
              startsGroup: true,
              endsGroup: true,
              startsPing: true,
              isAi: false,
              authorName: 'Deniz',
              dateMs: 0,
              startsTimeSection: true,
            ),
            TimelineItemMessage(
              id: 'c-1',
              contentKind: 'pending',
              contentId: 'c-1',
              side: 'person',
              startsGroup: true,
              endsGroup: true,
              startsPing: false,
              isAi: false,
              dateMs: 0,
              startsTimeSection: false,
            ),
            TimelineItemMessage(
              id: 'x',
              contentKind: 'hologram',
              contentId: 'x',
              side: 'middle',
              startsGroup: true,
              endsGroup: true,
              startsPing: false,
              isAi: false,
              dateMs: 0,
              startsTimeSection: false,
            ),
          ],
        ),
      );
      expect(state.phase, ConversationPhase.ready);
      expect(state.messages.single.id, 'msg_1');
      expect(state.pending.first.state, PendingState.failed);
      expect(state.pending.first.photos.single.sha256, 'ab');
      expect(state.pending.first.heldFor, isNull);
      expect(state.pending.first.isHeld, isFalse);
      expect(state.pending.last.heldFor, 'app_paused');
      expect(state.pending.last.isHeld, isTrue);
      expect(state.isOffline, isTrue);
      expect(state.isServerUnreachable, isTrue);
      expect(state.timeline, hasLength(2));
      expect(state.timeline.first.message!.id, 'msg_1');
      expect(state.timeline.first.startsPing, isTrue);
      expect(state.timeline.last.pending!.clientId, 'c-1');
      expect(state.timeline.last.side, TimelineSide.person);
      expect(state.canSend, isFalse);
      expect(state.closedReason, 'verification_required');
      expect(state.status, ThreadStatus.resolved);
      expect(state.typing!.isAi, isTrue);
      expect(state.live, LiveState.waiting);
      expect(state.liveRetryIn, const Duration(milliseconds: 1500));
      expect(state.coolingDown, {'messages'});
      expect(state.awaitingApproval, {'card_1'});
      expect(state.draft, 'half a thought');
      expect(state.composerInsertion, 'My alarm ');
      expect(state.isEmpty, isFalse);
    });

    test(
      'actions reach native with the ids of the cards and messages',
      () async {
        final message = decodeMessageJson(
          fixtureValues('sdk/Message.json').first,
        )!;
        final choices = (message.parts[1] as CardPart).card as ChoicesCard;
        final pending = PendingMessage(
          clientId: 'c-1',
          createdAt: DateTime.utc(2026),
          state: PendingState.failed,
          photos: const [
            PendingPhoto(width: 1, height: 1, bytes: 1, sha256: 'ab'),
          ],
        );
        when(() => host.conversationSend(any(), any()))
            .thenAnswer((_) async {});
        when(() => host.conversationRetry(any())).thenAnswer((_) async {});
        when(() => host.conversationDiscard(any())).thenAnswer((_) async {});
        when(() => host.conversationLoadOlder()).thenAnswer((_) async {});
        when(() => host.conversationChoose(any(), any(), any()))
            .thenAnswer((_) async {});
        when(() => host.conversationRate(any(), any(), any()))
            .thenAnswer((_) async {});
        when(() => host.conversationOpenCard(any(), any()))
            .thenAnswer((_) async {});
        when(() => host.conversationSetTyping(any())).thenAnswer((_) async {});
        when(() => host.conversationReload()).thenAnswer((_) async {});
        when(() => host.conversationMarkRead()).thenAnswer((_) async {});
        when(() => host.conversationSetDraft(any())).thenAnswer((_) async {});
        when(() => host.conversationConsumeInsertion())
            .thenAnswer((_) async {});
        when(() => host.conversationPhotoData(any(), any()))
            .thenAnswer((_) async => Uint8List.fromList([1, 2]));
        when(() => host.conversationRefreshedImageUrl(any(), any()))
            .thenAnswer((_) async => 'https://files.example/new');
        when(() => host.conversationCooldownRemaining(any()))
            .thenAnswer((_) async => 2500);
        final conversation = PingFront.conversation;
        final photo = Uint8List.fromList([9]);
        await conversation.send('Hello', photos: [photo]);
        await conversation.retry(pending);
        await conversation.discard(pending);
        await conversation.loadOlder();
        await conversation.choose(choices.options.first, choices, message);
        await conversation.rate(
          4,
          const RatingCard(id: 'r1', question: '?', scale: 5),
          message,
        );
        await conversation.open(choices, message);
        await conversation.setTyping(true);
        await conversation.reload();
        await conversation.markRead();
        await conversation.updateDraft('draft');
        await conversation.consumeInsertion();
        expect(await conversation.photoData(pending, pending.photos.single), [
          1,
          2,
        ]);
        expect(
          await conversation.refreshedUrl(
            message,
            const ImagePart(attachmentId: 'att_1', width: 1, height: 1),
          ),
          'https://files.example/new',
        );
        expect(
          await conversation.cooldownRemaining('messages'),
          const Duration(milliseconds: 2500),
        );
        verifyInOrder([
          () => host.conversationSend('Hello', [photo]),
          () => host.conversationRetry('c-1'),
          () => host.conversationDiscard('c-1'),
          () => host.conversationLoadOlder(),
          () => host.conversationChoose('msg_1', 'c1', 'yes'),
          () => host.conversationRate('msg_1', 'r1', 4),
          () => host.conversationOpenCard('msg_1', 'c1'),
          () => host.conversationSetTyping(true),
          () => host.conversationReload(),
          () => host.conversationMarkRead(),
          () => host.conversationSetDraft('draft'),
          () => host.conversationConsumeInsertion(),
          () => host.conversationPhotoData('c-1', 'ab'),
          () => host.conversationRefreshedImageUrl('msg_1', 'att_1'),
          () => host.conversationCooldownRemaining('messages'),
        ]);
      },
    );

    test('reload completes only when the native reload has finished', () async {
      final finished = Completer<void>();
      when(() => host.conversationReload()).thenAnswer((_) => finished.future);
      var done = false;
      final reloading = PingFront.conversation.reload().then(
        (_) => done = true,
      );
      await pumpEventQueue();
      expect(done, isFalse);
      finished.complete();
      await reloading;
      expect(done, isTrue);
    });

    test('the state stream decodes each snapshot', () async {
      final states = <ConversationState>[];
      final sub = PingFront.conversation.states.listen(states.add);
      platform.conversation$.add(conversationMessage(messagesJson: '[]'));
      await pumpEventQueue();
      await sub.cancel();
      expect(states.single.isEmpty, isTrue);
      expect(states.single.hasOlder, isTrue);
    });

    test('a stale id from native becomes PingFrontException', () async {
      when(() => host.conversationRetry(any())).thenThrow(
        PlatformException(code: 'invalid_input', message: 'No pending message'),
      );
      await expectLater(
        PingFront.conversation.retry(
          PendingMessage(
            clientId: 'gone',
            createdAt: DateTime.utc(2026),
            state: PendingState.failed,
          ),
        ),
        throwsA(isA<PingFrontException>()),
      );
    });
  });

  group('PingFrontChatView', () {
    testWidgets(
      'Android: only the padding ancestors left reaches native; Flutter owns the keyboard',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        when(() => host.setChatViewPadding(any(), any(), any(), any(), any()))
            .thenAnswer((_) async {});
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async => call.method == 'create' ? 0 : null,
        );
        Widget chat(
          EdgeInsets padding, {
          EdgeInsets viewInsets = EdgeInsets.zero,
        }) => MediaQuery(
          data: MediaQueryData(
            padding: padding,
            viewInsets: viewInsets,
            size: const Size(800, 600),
          ),
          child: const Directionality(
            textDirection: TextDirection.ltr,
            child: PingFrontChatView(),
          ),
        );
        await tester.pumpWidget(chat(const EdgeInsets.only(bottom: 24)));
        await tester.pump();
        // The keyboard opens: Flutter's padding drops the part the keyboard covers, and the keyboard
        // itself never reaches native (the Scaffold or Dialog lays the view out above it).
        await tester.pumpWidget(
          chat(EdgeInsets.zero, viewInsets: const EdgeInsets.only(bottom: 300)),
        );
        await tester.pump();
        verify(() => host.setChatViewPadding(0, 0, 0, 0, 0)).called(1);
        verifyNever(
          () => host.setChatViewPadding(any(), any(), any(), any(), 300),
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'a calm placeholder covers the view until native shows its first frame',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        await PingFront.configure('pk_test_abcdefghijklmnopqrstuvvd');
        int? viewId;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async {
            if (call.method == 'create') {
              viewId = (call.arguments as Map<Object?, Object?>)['id']! as int;
            }
            return null;
          },
        );
        await tester.pumpWidget(
          const Directionality(
            textDirection: TextDirection.ltr,
            child: PingFrontChatView(),
          ),
        );
        await tester.pump();
        final placeholder = find.byKey(PingFrontChatView.placeholderKey);
        expect(placeholder, findsOneWidget);
        // Before the look arrives: the platform's default chat background, never transparent.
        expect(
          tester.widget<ColoredBox>(placeholder).color,
          const Color(0xFFFFFFFF),
        );
        expect(viewId, isNotNull);
        // Another view's first frame changes nothing.
        platform.flutterApi!.onChatViewShown(viewId! + 1000);
        await tester.pump();
        expect(placeholder, findsOneWidget);
        platform.flutterApi!.onChatViewShown(viewId!);
        await tester.pump();
        expect(placeholder, findsNothing);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets(
      'the topic applies once: a view recreated after offstage gets none',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final topics = <Object?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async {
            if (call.method == 'create') {
              final args = call.arguments as Map<Object?, Object?>;
              final params = const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(args['params']! as Uint8List),
              ) as Map<Object?, Object?>;
              topics.add(params['topic']);
            }
            return null;
          },
        );
        Widget tabs(int index, ChatTopic topic) => Directionality(
          textDirection: TextDirection.ltr,
          child: IndexedStack(
            index: index,
            children: [
              const SizedBox(),
              PingFrontChatView(topic: topic),
            ],
          ),
        );
        await tester.pumpWidget(tabs(1, ChatTopic.billing));
        await tester.pumpWidget(tabs(0, ChatTopic.billing));
        await tester.pumpWidget(tabs(1, ChatTopic.billing));
        // A new topic applies again.
        await tester.pumpWidget(tabs(1, ChatTopic.bug));
        expect(topics.map((t) => (t as Map<Object?, Object?>?)?['id']), [
          'billing',
          null,
          'bug',
        ]);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('the placeholder follows the look as it changes', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async => null,
      );
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PingFrontChatView(),
        ),
      );
      final look = lookMessage(scheme: 'light')
        ..background = ColorMessage(light: '#ABCDEF', dark: '#123456');
      platform.looks$.add(look);
      await tester.pump();
      expect(
        tester
            .widget<ColoredBox>(find.byKey(PingFrontChatView.placeholderKey))
            .color,
        const Color(0xFFABCDEF),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    test('creation parameters carry the topic', () {
      expect(PingFrontChatView.creationParams(null), {
        'topic': null,
        'padding': [0.0, 0.0, 0.0, 0.0],
      });
      expect(
        PingFrontChatView.creationParams(
          const ChatTopic('sync', label: 'Sync', prefill: 'Sync stopped '),
        ),
        {
          'topic': {
            'id': 'sync',
            'label': 'Sync',
            'symbol': 'other',
            'prefill': 'Sync stopped ',
          },
          'padding': [0.0, 0.0, 0.0, 0.0],
        },
      );
    });

    testWidgets('iOS hosts the native view under its view type', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PingFrontChatView(topic: ChatTopic.billing),
        ),
      );
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(view.viewType, Brand.chatViewType);
      expect((view.creationParams! as Map<String, Object?>)['topic'], {
        'id': 'billing',
        'label': null,
        'symbol': 'billing',
        'prefill': null,
      });
      expect(view.gestureRecognizers, isNotEmpty);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android uses hybrid composition under its view type', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: PingFrontChatView(),
        ),
      );
      final link = tester.widget<PlatformViewLink>(
        find.byType(PlatformViewLink),
      );
      expect(link.viewType, Brand.chatViewType);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets(
      'offstage (another tab, a route on top) there is no native view',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        Widget tabs(int index) => Directionality(
          textDirection: TextDirection.ltr,
          child: IndexedStack(
            index: index,
            children: const [SizedBox(), PingFrontChatView()],
          ),
        );
        await tester.pumpWidget(tabs(1));
        expect(find.byType(UiKitView), findsOneWidget);
        await tester.pumpWidget(tabs(0));
        expect(find.byType(UiKitView, skipOffstage: false), findsNothing);
        await tester.pumpWidget(tabs(1));
        expect(find.byType(UiKitView), findsOneWidget);
        debugDefaultTargetPlatformOverride = null;
      },
    );

    testWidgets('a new topic makes a new native view', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Widget chat(ChatTopic topic) => Directionality(
        textDirection: TextDirection.ltr,
        child: PingFrontChatView(topic: topic),
      );
      await tester.pumpWidget(chat(ChatTopic.billing));
      final first = tester.element(find.byType(UiKitView));
      await tester.pumpWidget(chat(ChatTopic.bug));
      expect(tester.element(find.byType(UiKitView)), isNot(same(first)));
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
