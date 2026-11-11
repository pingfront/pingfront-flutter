import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'messages.g.dart';
import 'results.dart' show PingFrontException;
import 'thread.dart';

/// Loading state of the thread.
enum ConversationPhase {
  /// Nothing loaded yet.
  idle,

  /// Loading the latest page.
  loading,

  /// Loaded (possibly from cache while offline).
  ready,

  /// Loading failed and nothing is cached.
  failed,

  /// A phase this version does not know.
  unknown,
}

/// Delivery state of a pending message.
enum PendingState {
  /// Waiting to be sent (also while offline or rate limited).
  queued,

  /// Being uploaded or sent right now.
  sending,

  /// The server rejected it: retry or discard. A held one ([PendingMessage.isHeld]) waits instead.
  failed,

  /// A state this version does not know.
  unknown,
}

/// A photo staged for upload.
@immutable
class PendingPhoto {
  /// Creates a photo.
  const PendingPhoto({
    required this.width,
    required this.height,
    required this.bytes,
    required this.sha256,
    this.attachmentId,
  });

  /// Pixel width.
  final int width;

  /// Pixel height.
  final int height;

  /// Byte count.
  final int bytes;

  /// Hex SHA-256 of the JPEG.
  final String sha256;

  /// Set once uploaded.
  final String? attachmentId;
}

/// A message the person wrote that the server has not acknowledged yet.
@immutable
class PendingMessage {
  /// Creates a pending message.
  const PendingMessage({
    required this.clientId,
    required this.createdAt,
    required this.state,
    this.text,
    this.photos = const [],
    this.attempts = 0,
    this.failure,
    this.heldFor,
  });

  /// The idempotency key; a retry reuses it.
  final String clientId;

  /// Text, if any.
  final String? text;

  /// Photos, if any.
  final List<PendingPhoto> photos;

  /// When the person tapped Send.
  final DateTime createdAt;

  /// Delivery attempts so far.
  final int attempts;

  /// Queued, sending or failed.
  final PendingState state;

  /// Why it failed, in plain words.
  final String? failure;

  /// Why a closed policy holds it: `app_paused` or `verification_required` (or a newer code), else
  /// `null`. A held message is [PendingState.failed] but needs nothing from the person: the native
  /// outbox sends it again by itself, first, when sending reopens, and the messages behind it wait for
  /// it. Show it as waiting, not with Try again. A blocked person's message is never held.
  final String? heldFor;

  /// True when a closed policy holds it (see [heldFor]).
  bool get isHeld => heldFor != null;
}

/// Which side of the thread a row sits on.
enum TimelineSide {
  /// Start side: team and assistant.
  team,

  /// End side: the person.
  person,

  /// Centered: receipts and system lines.
  system,

  /// A side this version does not know; show it like [team].
  unknown,
}

/// One row of the timeline with its grouping, as the native chat groups it.
@immutable
class TimelineItem {
  /// Creates a row.
  const TimelineItem({
    required this.id,
    required this.side,
    required this.startsGroup,
    required this.endsGroup,
    required this.startsPing,
    required this.isAi,
    required this.date,
    required this.startsTimeSection,
    this.message,
    this.pending,
    this.authorName,
  });

  /// Stable id (the message id or client id).
  final String id;

  /// The delivered message, or `null` for a pending row.
  final Message? message;

  /// The pending message, or `null` for a delivered row.
  final PendingMessage? pending;

  /// Which side.
  final TimelineSide side;

  /// First row of a group from the same author (show the author name).
  final bool startsGroup;

  /// Last row of a group (show the timestamp, avatar, hand-off line).
  final bool endsGroup;

  /// First row of a run of pings (show the ping mark and its line).
  final bool startsPing;

  /// Written by the assistant (always labelled).
  final bool isAi;

  /// The author's display name.
  final String? authorName;

  /// When it was written.
  final DateTime date;

  /// First row after a pause of more than 5 minutes (or the first row): show a time caption.
  final bool startsTimeSection;
}

/// Open or resolved.
enum ThreadStatus {
  /// Open.
  open,

  /// Resolved.
  resolved,

  /// A status this version does not know; show it like [open].
  unknown,
}

/// The live channel's state.
enum LiveState {
  /// Not connected.
  stopped,

  /// Opening the socket.
  connecting,

  /// Receiving events.
  live,

  /// Disconnected; retrying after [ConversationState.liveRetryIn].
  waiting,

  /// A state this version does not know.
  unknown,
}

/// Who is typing.
@immutable
class TypingIndicator {
  /// Creates an indicator.
  const TypingIndicator({required this.isAi, this.name});

  /// The teammate or assistant name.
  final String? name;

  /// True when the assistant is typing.
  final bool isAi;
}

/// One snapshot of the thread, for building your own chat UI.
@immutable
class ConversationState {
  /// Creates a snapshot.
  const ConversationState({
    this.phase = ConversationPhase.idle,
    this.failureCode,
    this.messages = const [],
    this.pending = const [],
    this.timeline = const [],
    this.hasOlder = false,
    this.isLoadingOlder = false,
    this.team = const [],
    this.replyExpectation,
    this.canSend = true,
    this.closedReason,
    this.status = ThreadStatus.open,
    this.typing,
    this.live = LiveState.stopped,
    this.liveRetryIn,
    this.liveOffline = false,
    this.teamReadSeq = 0,
    this.isOffline = false,
    this.isServerUnreachable = false,
    this.draft = '',
    this.composerInsertion,
    this.coolingDown = const {},
    this.awaitingApproval = const {},
  });

  /// The empty state before anything loaded.
  static const ConversationState empty = ConversationState();

  /// Loading state.
  final ConversationPhase phase;

  /// For [ConversationPhase.failed]: the error code (iOS), or `network` when the device looked
  /// offline (Android, which reports only that).
  final String? failureCode;

  /// Messages in sequence order.
  final List<Message> messages;

  /// Messages the person sent that the server has not acknowledged.
  final List<PendingMessage> pending;

  /// The rows to render: messages and pending sends, grouped.
  final List<TimelineItem> timeline;

  /// True when older messages can be loaded ([PingFrontConversation.loadOlder]).
  final bool hasOlder;

  /// True while older messages load.
  final bool isLoadingOlder;

  /// The team, for the header and welcome.
  final List<TeamMember> team;

  /// The server's reply expectation, already localized.
  final String? replyExpectation;

  /// Whether the person can send.
  final bool canSend;

  /// Why sending is off: `blocked`, `app_paused`, `verification_required`, or a newer code.
  final String? closedReason;

  /// Open or resolved.
  final ThreadStatus status;

  /// Who is typing right now.
  final TypingIndicator? typing;

  /// The live channel's state.
  final LiveState live;

  /// For [LiveState.waiting]: time until the next attempt.
  final Duration? liveRetryIn;

  /// For [LiveState.waiting]: the device looked offline.
  final bool liveOffline;

  /// The highest sequence number the team has read.
  final int teamReadSeq;

  /// True when the chat can't reach the service: the device looks offline, or the last request could
  /// not get through.
  final bool isOffline;

  /// Of [isOffline]: the device has a network, but the last request could not reach the service (its
  /// name did not resolve, or the connection was refused). Say the chat can't be reached instead of
  /// "offline". Cleared by the next request that gets through.
  final bool isServerUnreachable;

  /// The person's unsent text (kept between launches).
  final String draft;

  /// Text to put into the composer once (a topic's prefill); call
  /// [PingFrontConversation.consumeInsertion] after using it.
  final String? composerInsertion;

  /// Rate-limit scopes cooling down (`messages`, `uploads`, …).
  final Set<String> coolingDown;

  /// iOS: offer card ids whose purchase waits for approval (Ask to Buy).
  final Set<String> awaitingApproval;

  /// True when there are no messages and nothing is pending (show a welcome).
  bool get isEmpty => messages.isEmpty && pending.isEmpty;
}

T _named<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

DateTime _ms(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

/// Decodes a conversation snapshot.
ConversationState decodeConversation(ConversationMessage m) {
  final messages = decodeMessagesJson(m.messagesJson);
  final pending = [
    for (final p in m.pending)
      PendingMessage(
        clientId: p.clientId,
        text: p.text,
        photos: [
          for (final photo in p.photos)
            PendingPhoto(
              width: photo.width,
              height: photo.height,
              bytes: photo.bytes,
              sha256: photo.sha256,
              attachmentId: photo.attachmentId,
            ),
        ],
        createdAt: _ms(p.createdAtMs),
        attempts: p.attempts,
        state: _named(PendingState.values, p.state, PendingState.unknown),
        failure: p.failure,
        heldFor: (p.heldFor?.isEmpty ?? true) ? null : p.heldFor,
      ),
  ];
  final byId = {for (final message in messages) message.id: message};
  final byClientId = {for (final p in pending) p.clientId: p};
  final timeline = <TimelineItem>[];
  for (final row in m.timeline) {
    final message = row.contentKind == 'message' ? byId[row.contentId] : null;
    final pendingRow = row.contentKind == 'pending'
        ? byClientId[row.contentId]
        : null;
    // A row whose content did not decode (or a content kind this version does not know) is skipped.
    if (message == null && pendingRow == null) continue;
    timeline.add(
      TimelineItem(
        id: row.id,
        message: message,
        pending: pendingRow,
        side: _named(TimelineSide.values, row.side, TimelineSide.unknown),
        startsGroup: row.startsGroup,
        endsGroup: row.endsGroup,
        startsPing: row.startsPing,
        isAi: row.isAi,
        authorName: row.authorName,
        date: _ms(row.dateMs),
        startsTimeSection: row.startsTimeSection,
      ),
    );
  }
  final typingIsAi = m.typingIsAi;
  return ConversationState(
    phase: _named(ConversationPhase.values, m.phase, ConversationPhase.unknown),
    failureCode: m.failureCode,
    messages: messages,
    pending: pending,
    timeline: timeline,
    hasOlder: m.hasOlder,
    isLoadingOlder: m.isLoadingOlder,
    team: decodeTeamJson(m.teamJson),
    replyExpectation: m.replyExpectation,
    canSend: m.canSend,
    closedReason: m.closedReason,
    status: _named(ThreadStatus.values, m.status, ThreadStatus.unknown),
    typing: typingIsAi == null
        ? null
        : TypingIndicator(isAi: typingIsAi, name: m.typingName),
    live: _named(LiveState.values, m.live, LiveState.unknown),
    liveRetryIn: m.liveRetryInMs == null
        ? null
        : Duration(milliseconds: m.liveRetryInMs!),
    liveOffline: m.liveOffline,
    teamReadSeq: m.teamReadSeq,
    isOffline: m.isOffline,
    isServerUnreachable: m.isServerUnreachable,
    draft: m.draft,
    composerInsertion: m.composerInsertion,
    coolingDown: m.coolingDown.toSet(),
    awaitingApproval: m.awaitingApproval.toSet(),
  );
}

/// The thread as state plus the actions a chat UI needs, for apps that draw their own chat. Reach it
/// as `PingFront.conversation`.
///
/// The native SDK owns the thread: it loads it, queues and retries sends, and keeps the draft. Call
/// [reload] when your chat screen appears so the thread loads, and [markRead] while it shows the
/// thread so the team sees Read. The built-in chat (`openChat` or `PingFrontChatView`) does both by
/// itself, and also marks itself visible, which turns on live updates; a screen you draw yourself does
/// not count as a visible chat.
final class PingFrontConversation {
  /// Creates the conversation API over the host API and a snapshot stream (the plugin does this).
  PingFrontConversation(this._host, this._states);

  final PingFrontHostApi Function() _host;
  final Stream<ConversationMessage> Function() _states;

  /// The thread: the current snapshot first, then every change. One native listen serves every listener.
  Stream<ConversationState> get states =>
      _shared ??= _states().map(decodeConversation);

  Stream<ConversationState>? _shared;

  /// The current snapshot.
  Future<ConversationState> state() async =>
      decodeConversation(await _call(() => _host().conversationState()));

  /// Sends text and photos (any image bytes; the SDK re-encodes them as JPEG of at most 2 MB).
  /// Returns at once: the message shows as pending and the SDK delivers it, also after a relaunch.
  Future<void> send(String text, {List<Uint8List> photos = const []}) =>
      _call(() => _host().conversationSend(text, photos));

  /// Sends a failed message again with the same idempotency key (the built-in chat's Try again).
  Future<void> retry(PendingMessage message) =>
      _call(() => _host().conversationRetry(message.clientId));

  /// Removes a message from the queue unsent: a failed one, a held one ([PendingMessage.heldFor]), or
  /// one queued behind it. Deleting the first held message lets the ones behind it go.
  Future<void> discard(PendingMessage message) =>
      _call(() => _host().conversationDiscard(message.clientId));

  /// Loads the previous page (call when the top of your list appears).
  Future<void> loadOlder() => _call(() => _host().conversationLoadOlder());

  /// Picks an option on a choices card.
  Future<void> choose(ChoiceOption option, ChoicesCard card, Message message) =>
      _call(() => _host().conversationChoose(message.id, card.id, option.id));

  /// Rates on a rating card (clamped to `1…card.scale`).
  Future<void> rate(int rating, RatingCard card, Message message) =>
      _call(() => _host().conversationRate(message.id, card.id, rating));

  /// Opens a card's action (offer, review, link, report, store action), as a tap in the built-in chat
  /// does: `PingFront.onOffer` and `PingFront.onLink` run for offers and links.
  Future<void> open(MessageCard card, Message message) =>
      _call(() => _host().conversationOpenCard(message.id, card.id));

  /// Tells the team the person is typing (throttled by the SDK).
  Future<void> setTyping(bool typing) =>
      _call(() => _host().conversationSetTyping(typing));

  /// Loads the thread (and a session if needed); call it when your chat screen appears, or from a
  /// `RefreshIndicator`. Completes when the reload has finished: the thread is loaded, or the load
  /// failed. On failure the phase is [ConversationPhase.failed] only when there is nothing to show; a
  /// thread already on screen stays.
  Future<void> reload() => _call(() => _host().conversationReload());

  /// For a chat UI of your own: marks the messages on screen as read, so the team sees Read and the
  /// unread count drops to 0. Call it when your screen shows the thread, and when new messages arrive
  /// while it does. Nothing is sent when there is nothing to mark, or while the app is paused. The
  /// built-in chat does this by itself.
  Future<void> markRead() => _call(() => _host().conversationMarkRead());

  /// Stores the person's unsent text (kept between launches).
  Future<void> updateDraft(String text) =>
      _call(() => _host().conversationSetDraft(text));

  /// Clears [ConversationState.composerInsertion] once your composer used it.
  Future<void> consumeInsertion() =>
      _call(() => _host().conversationConsumeInsertion());

  /// The JPEG bytes of a photo still waiting to be sent, for a thumbnail.
  Future<Uint8List?> photoData(PendingMessage message, PendingPhoto photo) =>
      _call(
        () => _host().conversationPhotoData(message.clientId, photo.sha256),
      );

  /// A fresh URL for an image whose short-lived URL expired.
  Future<String?> refreshedUrl(Message message, ImagePart image) => _call(
    () => _host().conversationRefreshedImageUrl(message.id, image.attachmentId),
  );

  /// Time left on a rate-limit cooldown (`messages`, `uploads`, …), or `null`.
  Future<Duration?> cooldownRemaining(String scope) async {
    final ms = await _call(() => _host().conversationCooldownRemaining(scope));
    return ms == null ? null : Duration(milliseconds: ms);
  }

  static Future<T> _call<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e) {
      throw PingFrontException(e.code, e.message ?? e.code);
    }
  }
}
