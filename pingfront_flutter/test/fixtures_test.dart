// The pingfront API's shared conformance fixtures (support.dart, fixturesPath). The plugin passes these
// wire shapes through from the native SDKs as JSON: messages and cards in the conversation state, the store offer on
// an offer card, and the message a live event carries. Every valid case decodes, and every value the plugin does not
// know decodes to an unknown case instead of throwing.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pingfront_flutter/src/thread.dart';

import 'support.dart';

final Directory _root = Directory(fixturesPath);

Map<String, Object?> _fixture(String file) =>
    jsonDecode(File('${_root.path}/$file').readAsStringSync())
        as Map<String, Object?>;

List<Map<String, Object?>> _cases(String file, [String key = 'valid']) =>
    ((_fixture(file)[key] as List?) ?? const []).cast<Map<String, Object?>>();

Map<String, Object?> _messageWithCard(Object? card, [Object? result]) => {
  'id': 'msg_1',
  'seq': 1,
  'author': {'kind': 'team'},
  'createdAt': '2026-11-01T10:00:00Z',
  'parts': [
    {'type': 'card', 'card': card, 'result': ?result},
  ],
};

const _knownParts = {'text', 'image', 'card', 'receipt'};

String _partType(MessagePart part) => switch (part) {
  TextPart() => 'text',
  ImagePart() => 'image',
  CardPart() => 'card',
  ReceiptPart() => 'receipt',
  UnknownPart(:final type) => 'unknown:$type',
};

void main() {
  test('reads the fixtures from the repository', () {
    expect(File('${_root.path}/sdk/Message.json').existsSync(), isTrue);
  });

  group('sdk/Message.json', () {
    for (final c in _cases('sdk/Message.json')) {
      test(c['name']! as String, () {
        final value = c['value']! as Map<String, Object?>;
        final message = decodeMessageJson(value);
        expect(message, isNotNull);
        expect(message!.id, value['id']);
        expect(message.seq, value['seq']);
        final parts = value['parts']! as List;
        expect(message.parts, hasLength(parts.length));
        for (var i = 0; i < parts.length; i++) {
          final wire = (parts[i] as Map)['type'] as String;
          final decoded = _partType(message.parts[i]);
          // A part type the plugin knows keeps it; anything else is unknown with its wire type.
          expect(decoded, _knownParts.contains(wire) ? wire : 'unknown:$wire');
        }
        // The same message as the conversation state carries it: a JSON array.
        expect(decodeMessagesJson(jsonEncode([value])), hasLength(1));
      });
    }

    test('an unknown part type, author kind and receipt action decode without throwing', () {
      final base =
          _cases('sdk/Message.json').first['value']! as Map<String, Object?>;
      final message = decodeMessageJson({
        ...base,
        'author': {'kind': 'robot_from_the_future'},
        'parts': [
          {'type': 'hologram', 'depth': 3},
          {'type': 'receipt', 'action': 'teleported', 'text': 'Moved'},
          'not an object',
        ],
      })!;
      expect(message.author.kind, AuthorKind.unknown);
      expect(_partType(message.parts[0]), 'unknown:hologram');
      expect(
        (message.parts[1] as ReceiptPart).action,
        const ReceiptAction('teleported'),
      );
      expect(message.parts[2], isA<UnknownPart>());
    });

    test('malformed messages are dropped, never thrown', () {
      final good = _cases('sdk/Message.json').first['value'];
      expect(
        decodeMessagesJson(
          jsonEncode([
            {'id': 'x'},
            7,
            null,
            good,
          ]),
        ),
        hasLength(1),
      );
      expect(decodeMessagesJson('not json'), isEmpty);
    });
  });

  group('sdk/ThreadResponse.json', () {
    for (final c in _cases('sdk/ThreadResponse.json')) {
      test(c['name']! as String, () {
        final messages =
            ((c['value']! as Map)['messages'] as List?) ?? const [];
        expect(
          decodeMessagesJson(jsonEncode(messages)),
          hasLength(messages.length),
        );
      });
    }
  });

  group('sdk/LinkCard.json', () {
    for (final c in _cases('sdk/LinkCard.json')) {
      test(c['name']! as String, () {
        final card = decodeCardJson(c['value']);
        expect(card, isA<LinkCard>());
        expect(card.id, (c['value']! as Map)['id']);
      });
    }
  });

  group('sdk/StoreActionCard.json', () {
    for (final c in _cases('sdk/StoreActionCard.json')) {
      test(c['name']! as String, () {
        final value = c['value']! as Map<String, Object?>;
        final card = decodeCardJson(value);
        expect(card, isA<StoreActionCard>());
        expect((card as StoreActionCard).action, value['action']);
      });
    }
  });

  test('a card kind the plugin does not know is UnknownCard with its kind', () {
    final card = decodeCardJson({'kind': 'poll', 'id': 'card_9'});
    expect(card, isA<UnknownCard>());
    expect((card as UnknownCard).wireKind, 'poll');
    expect(decodeCardJson('not a card'), isA<UnknownCard>());
  });

  group('sdk/CardResult.json', () {
    for (final c in [
      ..._cases('sdk/CardResult.json'),
      ..._cases('sdk/CardResult.json', 'unknown'),
    ]) {
      test(c['name']! as String, () {
        final message = decodeMessageJson(
          _messageWithCard({
            'kind': 'choices',
            'id': 'c1',
            'options': <Object?>[],
          }, c['value']),
        )!;
        final part = message.parts.single as CardPart;
        expect(part.result, isNotNull);
      });
    }
  });

  group('sdk/StoreOffer.json', () {
    for (final c in _cases('sdk/StoreOffer.json')) {
      test(c['name']! as String, () {
        final value = c['value']! as Map<String, Object?>;
        expect(decodeStoreOfferJson(value)?.kind, value['kind']);
      });
    }

    test('a kind the plugin does not know keeps its wire name', () {
      expect(
        decodeStoreOfferJson({'kind': 'lifetime_upgrade', 'id': 'x'})?.kind,
        'lifetime_upgrade',
      );
    });
  });

  group('live/ServerEvent.json', () {
    for (final c in _cases('live/ServerEvent.json')) {
      test(c['name']! as String, () {
        final event = c['value']! as Map<String, Object?>;
        // The message a live event carries is the one the conversation state passes through.
        if (event['type'] == 'message') {
          expect(decodeMessageJson(event['message']), isNotNull);
        } else {
          // Any other event is not a message: null, never a throw.
          expect(decodeMessageJson(event), isNull);
        }
      });
    }

    for (final c in _cases('live/ServerEvent.json', 'invalid')) {
      test('never throws on: ${c['name']}', () {
        final value = c['value'];
        expect(
          () => decodeMessageJson(value is Map ? value['message'] : value),
          returnsNormally,
        );
      });
    }
  });
}
