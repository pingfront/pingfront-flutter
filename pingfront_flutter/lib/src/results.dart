import 'package:flutter/foundation.dart';

import 'models.dart';
import 'pingfront.dart' show PingFront;

/// An error from the native SDK.
///
/// [code] is the server error code when there is one (`invalid_app_key`, `app_paused`, …), else
/// one of `network`, `not_configured`, `cooling_down`, `invalid_input`, `invalid_key`,
/// `session_changed`, `storage_unavailable`, `cancelled` or `unexpected`.
@immutable
class PingFrontException implements Exception {
  /// Creates an exception.
  const PingFrontException(this.code, this.message);

  /// A stable code.
  final String code;

  /// A developer-facing sentence (English). Show your own copy to people.
  final String message;

  @override
  String toString() => 'PingFrontException($code): $message';
}

/// What a silent push did, from [PingFront.handleBackgroundPush].
enum BackgroundPushResult {
  /// Something changed (a new chat look was fetched).
  newData,

  /// Nothing to do, or nothing changed.
  noData,

  /// The fetch failed (offline, server error).
  failed,
}

/// The outcome of [PingFront.selfCheck], as the native SDKs' `SetupCheckResult`.
@immutable
class SelfCheckResult {
  /// Creates a result.
  const SelfCheckResult({required this.passed, this.code, required this.line});

  /// True when the setup message reached the server.
  final bool passed;

  /// A stable failure code (`key_invalid`, `key_unknown`, `network`, `app_paused`, `timeout`,
  /// `not_configured`, …); `null` when it passed.
  final String? code;

  /// The one line: `PingFront self-check: PASS` or `PingFront self-check: FAIL <code>: <what to do>`.
  final String line;

  @override
  bool operator ==(Object other) =>
      other is SelfCheckResult &&
      other.passed == passed &&
      other.code == code &&
      other.line == line;

  @override
  int get hashCode => Object.hash(passed, code, line);

  @override
  String toString() => line;
}

/// The outcome of [PingFront.moment].
@immutable
sealed class MomentResult {
  const MomentResult();
}

/// No play listens to the moment, so nothing was sent.
final class MomentNotListened extends MomentResult {
  /// Creates the result.
  const MomentNotListened();
}

/// Sent; no play reacted.
final class MomentIgnored extends MomentResult {
  /// Creates the result.
  const MomentIgnored();
}

/// A play scheduled a ping.
final class MomentScheduled extends MomentResult {
  /// Creates the result.
  const MomentScheduled();
}

/// A ping was delivered now.
final class MomentDelivered extends MomentResult {
  /// Creates the result.
  const MomentDelivered();
}

/// The person is in a holdout group for this play.
final class MomentHeldOut extends MomentResult {
  /// Creates the result.
  const MomentHeldOut();
}

/// The server asked to open the chat. [presented] is false when
/// [PingFrontOptions.presentsChatForMoments] is off: open it yourself when it suits the screen.
final class MomentOpenRequested extends MomentResult {
  /// Creates the result.
  const MomentOpenRequested({required this.presented});

  /// True when the SDK presented the chat.
  final bool presented;
}

/// The name is invalid (`[a-z0-9][a-z0-9_.-]{0,63}`).
final class MomentInvalidName extends MomentResult {
  /// Creates the result.
  const MomentInvalidName();
}

/// Sending failed.
final class MomentFailed extends MomentResult {
  /// Creates the result.
  const MomentFailed(this.error);

  /// Why.
  final PingFrontException error;
}

/// A result this version of the plugin does not know.
final class MomentUnknown extends MomentResult {
  /// Creates the result.
  const MomentUnknown(this.kind);

  /// The native name of the result.
  final String kind;
}

/// A summary of a received message, safe to show in an in-app banner.
@immutable
class ReceivedMessage {
  /// Creates a summary.
  const ReceivedMessage({
    required this.id,
    required this.preview,
    required this.isPing,
    required this.isAi,
    this.authorName,
  });

  /// The message id.
  final String id;

  /// The author's display name.
  final String? authorName;

  /// The first text, truncated.
  final String preview;

  /// True when the team reached out before the person wrote.
  final bool isPing;

  /// True when the assistant wrote it.
  final bool isAi;
}

/// A summary of a message the person sent, for your analytics. It carries no message text.
@immutable
class SentMessage {
  /// Creates a summary.
  const SentMessage({
    required this.id,
    required this.textLength,
    required this.photoCount,
    required this.repliesToPing,
  });

  /// The message id.
  final String id;

  /// Characters of text (0 for a photo-only message).
  final int textLength;

  /// Photos attached.
  final int photoCount;

  /// True when the latest team message before it is a ping (the person is answering a ping).
  final bool repliesToPing;
}

/// A card kind, as on the wire (`offer`, `review`, …). Open: a kind this version does not know keeps its
/// wire name, so compare with `==` and keep a default branch.
@immutable
class CardKind {
  /// A kind from its wire name.
  const CardKind(this.name);

  /// The wire name.
  final String name;

  /// An offer card.
  static const CardKind offer = CardKind('offer');

  /// A review ask.
  static const CardKind review = CardKind('review');

  /// A link or deep link.
  static const CardKind link = CardKind('link');

  /// Quick choices.
  static const CardKind choices = CardKind('choices');

  /// A rating (CSAT).
  static const CardKind rating = CardKind('rating');

  /// Report a problem.
  static const CardKind report = CardKind('report');

  /// One of the store's own screens (manage subscription, refund, payment fix).
  static const CardKind storeAction = CardKind('store_action');

  /// The kinds this version knows.
  static const List<CardKind> known = [
    offer,
    review,
    link,
    choices,
    rating,
    report,
    storeAction,
  ];

  /// True when this version knows the kind.
  bool get isKnown => known.contains(this);

  @override
  bool operator ==(Object other) => other is CardKind && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

/// A card the person tapped or answered.
@immutable
class OpenedCard {
  /// Creates the summary.
  const OpenedCard({
    required this.kind,
    required this.cardId,
    required this.messageId,
  });

  /// What kind of card.
  final CardKind kind;

  /// The card id.
  final String cardId;

  /// The message the card is in.
  final String messageId;
}

/// Events from [PingFront.events].
///
/// New native events arrive as [PingFrontUnknownEvent], so switch with a default branch.
@immutable
sealed class PingFrontEvent {
  const PingFrontEvent();

  /// An event this version does not know, passed through with its native name and fields.
  const factory PingFrontEvent.unknown(String type, Map<String, Object?> data) =
      PingFrontUnknownEvent;
}

/// The chat became visible.
final class ChatOpened extends PingFrontEvent {
  /// Creates the event.
  const ChatOpened();
}

/// The chat was closed.
final class ChatClosed extends PingFrontEvent {
  /// Creates the event.
  const ChatClosed();
}

/// A team or assistant message arrived.
final class MessageReceived extends PingFrontEvent {
  /// Creates the event.
  const MessageReceived(this.message);

  /// The message summary.
  final ReceivedMessage message;
}

/// The server accepted a message the person wrote (after any queueing and photo uploads).
final class MessageSent extends PingFrontEvent {
  /// Creates the event.
  const MessageSent(this.message);

  /// The message summary.
  final SentMessage message;
}

/// The person tapped a card (offer, review, link, report, store action) or answered one (choices, rating).
final class CardOpened extends PingFrontEvent {
  /// Creates the event.
  const CardOpened(this.card);

  /// The card.
  final OpenedCard card;
}

/// The unread count changed.
final class UnreadChanged extends PingFrontEvent {
  /// Creates the event.
  const UnreadChanged(this.count);

  /// The new count.
  final int count;
}

/// A session started (lazily, on first use).
final class SessionStarted extends PingFrontEvent {
  /// Creates the event.
  const SessionStarted(this.person);

  /// The person.
  final PersonSummary person;
}

/// The server revoked this install: the native SDK cleared its local state, and the
/// next request (the next chat open) starts a new guest.
final class SessionRevoked extends PingFrontEvent {
  /// Creates the event.
  const SessionRevoked();
}

/// The server reported a problem with the identity token: `token_invalid`, `token_expired`,
/// `user_mismatch` or `unknown`.
final class IdentityProblemReported extends PingFrontEvent {
  /// Creates the event.
  const IdentityProblemReported(this.problem);

  /// The problem code.
  final String problem;
}

/// The person tapped an offer card.
final class OfferRequested extends PingFrontEvent {
  /// Creates the event.
  const OfferRequested(this.request);

  /// The request.
  final OfferRequest request;
}

/// A native offer module finished showing an offer.
final class OfferCompleted extends PingFrontEvent {
  /// Creates the event.
  const OfferCompleted(this.request, this.outcome, {this.failure});

  /// The request.
  final OfferRequest request;

  /// `purchased`, `pending`, `cancelled`, `unavailable`, `failed`, or one this version does not
  /// know.
  final String outcome;

  /// For `failed`: why (`network`, `product_not_found`, `billing_unavailable`, …).
  final String? failure;
}

/// The chat look changed (published, or a draft on a test device).
final class LookChanged extends PingFrontEvent {
  /// Creates the event.
  const LookChanged({required this.revision, required this.draft});

  /// The remote revision.
  final int revision;

  /// True for a draft.
  final bool draft;
}

/// A configuration problem was found.
final class ConfigurationProblemFound extends PingFrontEvent {
  /// Creates the event.
  const ConfigurationProblemFound(this.problem);

  /// The problem.
  final ConfigurationProblem problem;
}

/// A bug report was sent.
final class ReportSent extends PingFrontEvent {
  /// Creates the event.
  const ReportSent();
}

/// An event this version of the plugin does not know, passed through as is.
final class PingFrontUnknownEvent extends PingFrontEvent {
  /// Creates the event.
  const PingFrontUnknownEvent(this.type, this.data);

  /// The native event name.
  final String type;

  /// Its fields.
  final Map<String, Object?> data;
}
