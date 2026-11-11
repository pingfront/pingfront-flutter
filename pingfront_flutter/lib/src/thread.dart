// The thread as the wire carries it (the pingfront API's Message, MessagePart, Card and TeamMember schemas),
// decoded with the same rules as every SDK: an unknown part type, card kind or enum value becomes an
// "unknown" case, and a malformed message is dropped, never thrown.
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart' show StoreOffer;
import 'results.dart' show CardKind;

/// Text the team wrote, keyed by BCP 47 tag plus `default`.
@immutable
class LocalizedText {
  /// Creates localized text.
  const LocalizedText(this.values);

  /// Values by language tag.
  final Map<String, String> values;

  /// The text for a tag such as `pt-BR`: the exact tag, then the base language, then `default`.
  String? resolve(String languageTag) {
    final tag = languageTag.replaceAll('_', '-');
    final exact = values[tag];
    if (exact != null) return exact;
    for (final entry in values.entries) {
      if (entry.key.toLowerCase() == tag.toLowerCase()) return entry.value;
    }
    final base = values[tag.split('-').first.toLowerCase()];
    return base ?? values['default'];
  }

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(
    values.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// Who wrote a message.
enum AuthorKind {
  /// The person using the app.
  person,

  /// A teammate.
  team,

  /// The assistant. Its messages are always labelled.
  ai,

  /// A system line (receipts).
  system,

  /// A kind this version does not know; show it like a team message.
  unknown,
}

/// The author of a message.
@immutable
class Author {
  /// Creates an author.
  const Author({required this.kind, this.id, this.name, this.avatarUrl});

  /// Person, team, AI or system.
  final AuthorKind kind;

  /// The team member id.
  final String? id;

  /// The display name.
  final String? name;

  /// The avatar URL.
  final String? avatarUrl;
}

/// One part of a message. New part types arrive as [UnknownPart].
@immutable
sealed class MessagePart {
  const MessagePart();
}

/// Plain text.
final class TextPart extends MessagePart {
  /// Creates a text part.
  const TextPart(this.text);

  /// The text.
  final String text;
}

/// A photo.
final class ImagePart extends MessagePart {
  /// Creates an image part.
  const ImagePart({
    required this.attachmentId,
    required this.width,
    required this.height,
    this.url,
    this.removed = false,
  });

  /// The attachment id; refresh an expired [url] with `PingFront.conversation.refreshedUrl`.
  final String attachmentId;

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// A short-lived download URL.
  final String? url;

  /// The app's retention deleted the photo: show a placeholder and don't fetch it.
  final bool removed;
}

/// A card, with its result once the person acted.
final class CardPart extends MessagePart {
  /// Creates a card part.
  const CardPart(this.card, {this.result});

  /// The card.
  final MessageCard card;

  /// Set once the person acted.
  final CardResult? result;
}

/// What a receipt line records. Open: a newer action keeps its wire name; show it like [custom].
@immutable
class ReceiptAction {
  /// An action from its wire name.
  const ReceiptAction(this.name);

  /// The wire name (`trial_extended`, `handed_off`, …).
  final String name;

  /// A custom receipt.
  static const ReceiptAction custom = ReceiptAction('custom');

  /// The AI teammate handed the conversation to the team; nothing was done for the person.
  static const ReceiptAction handedOff = ReceiptAction('handed_off');

  @override
  bool operator ==(Object other) =>
      other is ReceiptAction && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// A centered system line recording something done for the person.
final class ReceiptPart extends MessagePart {
  /// Creates a receipt part.
  const ReceiptPart({required this.action, required this.text});

  /// What was done.
  final ReceiptAction action;

  /// For example "Trial extended to 14 Nov".
  final String text;
}

/// A part type this version does not know (or a malformed part). Show [Message.fallback] instead.
final class UnknownPart extends MessagePart {
  /// Creates the part.
  const UnknownPart(this.type);

  /// The wire type.
  final String type;
}

/// What the person did with a card.
@immutable
class CardResult {
  /// Creates a result.
  const CardResult({required this.at, this.choiceId, this.rating});

  /// When.
  final DateTime at;

  /// The option picked on a choices card.
  final String? choiceId;

  /// The rating given on a rating card.
  final int? rating;
}

/// A structured card inside a message. New kinds arrive as [UnknownCard].
@immutable
sealed class MessageCard {
  const MessageCard(this.id);

  /// The card id.
  final String id;

  /// The card's kind.
  CardKind get kind;
}

/// Opens the app's offer (paywall or promo) named by [offerId].
final class OfferCard extends MessageCard {
  /// Creates the card.
  const OfferCard({
    required String id,
    required this.offerId,
    required this.title,
    required this.button,
    this.body,
    this.offer,
  }) : super(id);

  @override
  CardKind get kind => CardKind.offer;

  /// The `OfferSlot.id` to show.
  final String offerId;

  /// The title.
  final String title;

  /// The body.
  final String? body;

  /// The button label.
  final String button;

  /// The store offer the button redeems, if any.
  final StoreOffer? offer;
}

/// How a review card asks.
enum ReviewMode {
  /// The store's native prompt.
  nativePrompt,

  /// The store page.
  storePage,

  /// A mode this version does not know.
  unknown,
}

/// Asks for a store review.
final class ReviewCard extends MessageCard {
  /// Creates the card.
  const ReviewCard({
    required String id,
    required this.mode,
    required this.button,
    this.storeUrl,
  }) : super(id);

  @override
  CardKind get kind => CardKind.review;

  /// Native prompt or store page.
  final ReviewMode mode;

  /// The store page URL.
  final String? storeUrl;

  /// The button label.
  final String button;
}

/// A link or deep link.
final class LinkCard extends MessageCard {
  /// Creates the card.
  const LinkCard({
    required String id,
    required this.title,
    required this.url,
    required this.button,
    this.screen,
    this.savedLinkId,
  }) : super(id);

  @override
  CardKind get kind => CardKind.link;

  /// The app screen the card opens (a saved link), handed to `PingFront.onScreen` when this build registered it.
  final LinkScreen? screen;

  /// The saved link the card was made from (set by the server).
  final String? savedLinkId;

  /// The title.
  final String title;

  /// A web URL or an app deep link. With [screen], the fallback for builds that didn't register it, or `''`.
  final String url;

  /// The button label.
  final String button;
}

/// A screen of the app that a link card opens, and its parameters (https://pingfront.sh/docs/offers#saved-links).
@immutable
class LinkScreen {
  /// Creates a screen target.
  const LinkScreen({required this.id, this.params = const {}});

  /// The screen's id, one the app registered (`AppScreen.id`).
  final String id;

  /// String parameters for the screen (`{'tab': 'yearly'}`), as the team set them.
  final Map<String, String> params;

  @override
  bool operator ==(Object other) =>
      other is LinkScreen &&
      other.id == id &&
      other.params.length == params.length &&
      params.entries.every((e) => other.params[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    id,
    Object.hashAllUnordered(
      params.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'LinkScreen($id, $params)';
}

LinkScreen? _linkScreen(Object? raw) {
  final json = _obj(raw);
  final id = json == null ? null : _str(json, 'id');
  if (json == null || id == null || id.isEmpty) return null;
  final params = <String, String>{};
  final rawParams = _obj(json['params']);
  if (rawParams != null) {
    for (final entry in rawParams.entries) {
      final value = entry.value;
      if (value is String) params[entry.key] = value;
    }
  }
  return LinkScreen(id: id, params: params);
}

/// One option of a choices card.
@immutable
class ChoiceOption {
  /// Creates an option.
  const ChoiceOption({required this.id, required this.label});

  /// The option id.
  final String id;

  /// The label.
  final String label;
}

/// The person picks one option.
final class ChoicesCard extends MessageCard {
  /// Creates the card.
  const ChoicesCard({required String id, required this.options}) : super(id);

  @override
  CardKind get kind => CardKind.choices;

  /// The options.
  final List<ChoiceOption> options;
}

/// A rating (CSAT).
final class RatingCard extends MessageCard {
  /// Creates the card.
  const RatingCard({
    required String id,
    required this.question,
    required this.scale,
  }) : super(id);

  @override
  CardKind get kind => CardKind.rating;

  /// The question.
  final String question;

  /// The highest rating (5).
  final int scale;
}

/// Opens the bug report.
final class ReportCard extends MessageCard {
  /// Creates the card.
  const ReportCard({
    required String id,
    required this.title,
    required this.button,
  }) : super(id);

  @override
  CardKind get kind => CardKind.report;

  /// The title.
  final String title;

  /// The button label.
  final String button;
}

/// Opens one of the store's own screens (manage subscription, refund, fix payment).
final class StoreActionCard extends MessageCard {
  /// Creates the card.
  const StoreActionCard({
    required String id,
    required this.action,
    this.title,
    this.body,
    this.button,
    this.productId,
    this.subscriptionGroupId,
    this.store,
  }) : super(id);

  @override
  CardKind get kind => CardKind.storeAction;

  /// The store action (`manage_subscription`, `request_refund`, …, or one this version does not know).
  final String action;

  /// The title.
  final String? title;

  /// The body.
  final String? body;

  /// The button label; `null` uses the SDK's label for the action.
  final String? button;

  /// The product.
  final String? productId;

  /// iOS: the subscription group the manage sheet opens on.
  final String? subscriptionGroupId;

  /// `app_store` or `play`: which store the card was written for.
  final String? store;
}

/// A card kind this version does not know (or a malformed card). Skip it, or show [Message.fallback].
final class UnknownCard extends MessageCard {
  /// Creates the card.
  const UnknownCard({required String id, required this.wireKind}) : super(id);

  /// The wire kind.
  final String wireKind;

  @override
  CardKind get kind => CardKind(wireKind);
}

/// Who reached out first.
enum PingKind {
  /// A teammate wrote first.
  manual,

  /// A play (rule) sent it.
  play,

  /// A kind this version does not know.
  unknown,
}

/// Why a team message arrived before the person wrote.
@immutable
class PingOrigin {
  /// Creates an origin.
  const PingOrigin({
    required this.kind,
    required this.explanation,
    this.playId,
    this.reasonCode,
    this.reasonParams = const {},
  });

  /// Manual or play.
  final PingKind kind;

  /// The play that sent it.
  final String? playId;

  /// Written by the server in the person's language ("Sent automatically after you closed Plans").
  final String explanation;

  /// `manual`, `moment`, `store_event`, `scheduled`, or a newer code.
  final String? reasonCode;

  /// The reason's parameters, for example the moment name.
  final Map<String, String> reasonParams;
}

/// A machine translation of a message's text parts.
@immutable
class MessageTranslation {
  /// Creates a translation.
  const MessageTranslation({
    required this.language,
    required this.texts,
    this.from,
  });

  /// The target language tag.
  final String language;

  /// The language the message was written in, when the server knows it.
  final String? from;

  /// The translated text parts.
  final List<String> texts;
}

/// A message in the thread.
@immutable
class Message {
  /// Creates a message.
  const Message({
    required this.id,
    required this.seq,
    required this.author,
    required this.parts,
    required this.createdAt,
    this.clientId,
    this.ping,
    this.fallback,
    this.translation,
  });

  /// The server id.
  final String id;

  /// Its position in the thread.
  final int seq;

  /// The sender's idempotency key (messages the person sent from an SDK).
  final String? clientId;

  /// Who wrote it.
  final Author author;

  /// Text, photos, cards and receipts.
  final List<MessagePart> parts;

  /// When the server accepted it.
  final DateTime createdAt;

  /// Set when the team reached out before the person wrote.
  final PingOrigin? ping;

  /// Plain text for parts and cards this version does not know.
  final String? fallback;

  /// The machine translation, when on.
  final MessageTranslation? translation;

  /// The text of all text parts, joined by newlines.
  String get plainText =>
      parts.whereType<TextPart>().map((p) => p.text).join('\n');

  /// True for messages the person wrote (on this or another device).
  bool get isFromPerson => author.kind == AuthorKind.person;
}

/// A member of the app's team.
@immutable
class TeamMember {
  /// Creates a member.
  const TeamMember({
    required this.id,
    required this.name,
    this.role,
    this.avatarUrl,
    this.timeZone,
  });

  /// The member id.
  final String id;

  /// The display name.
  final String name;

  /// For example "Maker of Clockwise".
  final String? role;

  /// The avatar URL.
  final String? avatarUrl;

  /// The IANA time zone ("21:40 for Deniz").
  final String? timeZone;
}

// Wire decoding.

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  final camel = raw.replaceAllMapped(
    RegExp('_([a-z])'),
    (m) => m.group(1)!.toUpperCase(),
  );
  for (final value in values) {
    if (value.name == camel) return value;
  }
  return fallback;
}

String? _str(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is String ? value : null;
}

int? _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is double && value == value.roundToDouble()) return value.toInt();
  return null;
}

Map<String, Object?>? _obj(Object? value) {
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

DateTime? _date(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toUtc();
}

Never _malformed(String what) => throw FormatException(what);

/// Decodes a `StoreOffer`, or `null` when it is malformed. An unknown kind keeps its wire name.
StoreOffer? decodeStoreOfferJson(Object? raw) {
  final json = _obj(raw);
  if (json == null) return null;
  final kind = _str(json, 'kind');
  final id = _str(json, 'id');
  if (kind == null || id == null) return null;
  return StoreOffer(
    kind: kind,
    id: id,
    productId: _str(json, 'productId'),
    basePlanId: _str(json, 'basePlanId'),
    offerId: _str(json, 'offerId'),
  );
}

/// Decodes a `MessageCard`. A kind this version does not know, or a malformed card, becomes [UnknownCard].
MessageCard decodeCardJson(Object? raw) {
  final json = _obj(raw) ?? const {};
  final kind = _str(json, 'kind') ?? '';
  final id = _str(json, 'id') ?? '';
  try {
    if (id.isEmpty) _malformed('card id');
    switch (kind) {
      case 'offer':
        return OfferCard(
          id: id,
          offerId: _str(json, 'offerId') ?? _malformed('offerId'),
          title: _str(json, 'title') ?? _malformed('title'),
          button: _str(json, 'button') ?? _malformed('button'),
          body: _str(json, 'body'),
          offer: decodeStoreOfferJson(json['offer']),
        );
      case 'review':
        return ReviewCard(
          id: id,
          mode: _enum(ReviewMode.values, json['mode'], ReviewMode.unknown),
          storeUrl: _str(json, 'storeUrl'),
          button: _str(json, 'button') ?? _malformed('button'),
        );
      case 'link':
        return LinkCard(
          id: id,
          title: _str(json, 'title') ?? _malformed('title'),
          url: _str(json, 'url') ?? _malformed('url'),
          button: _str(json, 'button') ?? _malformed('button'),
          // A malformed screen is dropped; the card keeps its url.
          screen: _linkScreen(json['screen']),
          savedLinkId: _str(json, 'savedLinkId'),
        );
      case 'choices':
        final options = json['options'];
        if (options is! List) _malformed('options');
        return ChoicesCard(
          id: id,
          options: [
            for (final option
                in options.map(_obj).whereType<Map<String, Object?>>())
              if (_str(option, 'id') != null && _str(option, 'label') != null)
                ChoiceOption(
                  id: _str(option, 'id')!,
                  label: _str(option, 'label')!,
                ),
          ],
        );
      case 'rating':
        return RatingCard(
          id: id,
          question: _str(json, 'question') ?? _malformed('question'),
          scale: _integer(json, 'scale') ?? 5,
        );
      case 'report':
        return ReportCard(
          id: id,
          title: _str(json, 'title') ?? _malformed('title'),
          button: _str(json, 'button') ?? _malformed('button'),
        );
      case 'store_action':
        return StoreActionCard(
          id: id,
          action: _str(json, 'action') ?? _malformed('action'),
          title: _str(json, 'title'),
          body: _str(json, 'body'),
          button: _str(json, 'button'),
          productId: _str(json, 'productId'),
          subscriptionGroupId: _str(json, 'subscriptionGroupId'),
          store: _str(json, 'store'),
        );
      default:
        return UnknownCard(id: id, wireKind: kind);
    }
  } on FormatException {
    return UnknownCard(id: id, wireKind: kind);
  }
}

/// Decodes a `MessagePart`. A type this version does not know, or a malformed part, becomes [UnknownPart].
MessagePart decodePartJson(Object? raw) {
  final json = _obj(raw) ?? const {};
  final type = _str(json, 'type') ?? '';
  switch (type) {
    case 'text':
      final text = _str(json, 'text');
      return text == null ? UnknownPart(type) : TextPart(text);
    case 'image':
      final id = _str(json, 'attachmentId');
      final width = _integer(json, 'width');
      final height = _integer(json, 'height');
      if (id == null || width == null || height == null) {
        return UnknownPart(type);
      }
      final removed = json['removed'] == true;
      return ImagePart(
        attachmentId: id,
        width: width,
        height: height,
        // A removed photo has no bytes: nothing should try to fetch it.
        url: removed ? null : _str(json, 'url'),
        removed: removed,
      );
    case 'card':
      final card = _obj(json['card']);
      if (card == null) return UnknownPart(type);
      final result = _obj(json['result']);
      final at = result == null ? null : _date(result['at']);
      return CardPart(
        decodeCardJson(card),
        result: at == null
            ? null
            : CardResult(
                at: at,
                choiceId: _str(result!, 'choiceId'),
                rating: _integer(result, 'rating'),
              ),
      );
    case 'receipt':
      final action = _str(json, 'action');
      final text = _str(json, 'text');
      if (action == null || text == null) return UnknownPart(type);
      return ReceiptPart(action: ReceiptAction(action), text: text);
    default:
      return UnknownPart(type);
  }
}

PingOrigin? _ping(Object? raw) {
  final json = _obj(raw);
  if (json == null) return null;
  final explanation = _str(json, 'explanation');
  if (explanation == null) return null;
  final reason = _obj(json['reason']);
  final params = _obj(reason?['params']);
  return PingOrigin(
    kind: _enum(PingKind.values, json['kind'], PingKind.unknown),
    playId: _str(json, 'playId'),
    explanation: explanation,
    reasonCode: reason == null ? null : _str(reason, 'code'),
    reasonParams: {
      for (final entry in (params ?? const <String, Object?>{}).entries)
        if (entry.value is String) entry.key: entry.value! as String,
    },
  );
}

MessageTranslation? _translation(Object? raw) {
  final json = _obj(raw);
  if (json == null) return null;
  final language = _str(json, 'language');
  final parts = json['parts'];
  if (language == null || parts is! List) return null;
  return MessageTranslation(
    language: language,
    from: _str(json, 'from'),
    texts: [
      for (final part in parts.map(decodePartJson))
        if (part is TextPart) part.text,
    ],
  );
}

/// Decodes a `Message`, or `null` when a required field is missing.
Message? decodeMessageJson(Object? raw) {
  final json = _obj(raw);
  if (json == null) return null;
  final id = _str(json, 'id');
  final seq = _integer(json, 'seq');
  final author = _obj(json['author']);
  final parts = json['parts'];
  final createdAt = _date(json['createdAt']);
  if (id == null ||
      seq == null ||
      author == null ||
      parts is! List ||
      createdAt == null) {
    return null;
  }
  return Message(
    id: id,
    seq: seq,
    clientId: _str(json, 'clientId'),
    author: Author(
      kind: _enum(AuthorKind.values, author['kind'], AuthorKind.unknown),
      id: _str(author, 'id'),
      name: _str(author, 'name'),
      avatarUrl: _str(author, 'avatarUrl'),
    ),
    parts: parts.map(decodePartJson).toList(growable: false),
    createdAt: createdAt,
    ping: _ping(json['ping']),
    fallback: _str(json, 'fallback'),
    translation: _translation(json['translation']),
  );
}

/// Decodes a JSON array of messages, dropping malformed ones.
List<Message> decodeMessagesJson(String text) {
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return raw
      .map(decodeMessageJson)
      .whereType<Message>()
      .toList(growable: false);
}

/// Decodes a `TeamMember`, or `null` when it is malformed.
TeamMember? decodeTeamMemberJson(Object? raw) {
  final json = _obj(raw);
  if (json == null) return null;
  final id = _str(json, 'id');
  final name = _str(json, 'name');
  if (id == null || name == null) return null;
  return TeamMember(
    id: id,
    name: name,
    role: _str(json, 'role'),
    avatarUrl: _str(json, 'avatarUrl'),
    timeZone: _str(json, 'timeZone'),
  );
}

/// Decodes a JSON array of team members, dropping malformed ones.
List<TeamMember> decodeTeamJson(String text) {
  final Object? raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    return const [];
  }
  if (raw is! List) return const [];
  return raw
      .map(decodeTeamMemberJson)
      .whereType<TeamMember>()
      .toList(growable: false);
}
