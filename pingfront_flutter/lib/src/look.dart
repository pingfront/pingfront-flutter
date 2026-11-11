import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'messages.g.dart';
import 'models.dart';
import 'thread.dart';

/// A topic of the resolved look, with its texts in every language the team wrote.
@immutable
class LookTopic {
  /// Creates a topic.
  const LookTopic({
    required this.id,
    required this.symbol,
    this.label,
    this.prefill,
  });

  /// The topic id.
  final String id;

  /// The label per language; `null` for a preset the SDK translates itself.
  final LocalizedText? label;

  /// The chip symbol.
  final TopicSymbol symbol;

  /// The composer prefill per language.
  final LocalizedText? prefill;

  /// This topic for `PingFront.openChat`, with texts in [languageTag] (`default` when `null`).
  ChatTopic toChatTopic([String? languageTag]) {
    final tag = languageTag ?? 'default';
    return ChatTopic(
      id,
      label: label?.resolve(tag),
      symbol: symbol,
      prefill: prefill?.resolve(tag),
    );
  }
}

/// The chat look the native SDK resolved: the dashboard's published look, then your code values,
/// then what it inferred from the app, then its defaults. Colors are already contrast-adjusted.
@immutable
class ResolvedLook {
  /// Creates a look.
  const ResolvedLook({
    required this.appName,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.teamBubble,
    required this.text,
    required this.muted,
    required this.scheme,
    required this.font,
    required this.corners,
    required this.density,
    required this.headerStyle,
    required this.showsLocalTime,
    required this.showsReplyExpectation,
    required this.showsWelcomeFaces,
    required this.topics,
    required this.allowsPhotos,
    required this.allowsReports,
    required this.showsNames,
    required this.showsAvatars,
    required this.timestamps,
    required this.aiName,
    required this.team,
    required this.isDraft,
    required this.revision,
    required this.bubbleRadius,
    this.appIconUrl,
    this.appIconPng,
    this.headerMemberId,
    this.headerTitle,
    this.welcomeTitle,
    this.welcomeBody,
    this.composerPlaceholder,
    this.replyExpectation,
  });

  /// The app name.
  final String appName;

  /// The app icon URL from the dashboard.
  final String? appIconUrl;

  /// The app icon the SDK read from the app (PNG), when it has one.
  final Uint8List? appIconPng;

  /// The person's bubbles and buttons.
  final PingFrontColor accent;

  /// Text on [accent].
  final PingFrontColor onAccent;

  /// The chat background.
  final PingFrontColor background;

  /// The team bubble fill.
  final PingFrontColor teamBubble;

  /// Body text.
  final PingFrontColor text;

  /// Secondary text.
  final PingFrontColor muted;

  /// Light, dark or automatic.
  final ChatScheme scheme;

  /// The font design.
  final ChatFont font;

  /// Bubble corners.
  final ChatCorners corners;

  /// Spacing density.
  final ChatDensity density;

  /// The header style.
  final ChatHeaderStyle headerStyle;

  /// The teammate the person header shows.
  final String? headerMemberId;

  /// The header title for the team and app styles.
  final LocalizedText? headerTitle;

  /// Show the teammate's local time.
  final bool showsLocalTime;

  /// Show the reply expectation.
  final bool showsReplyExpectation;

  /// The welcome title (`null`: the SDK's own).
  final LocalizedText? welcomeTitle;

  /// The welcome body (`null`: the SDK's own).
  final LocalizedText? welcomeBody;

  /// Show team faces on the welcome screen.
  final bool showsWelcomeFaces;

  /// Topic chips, at most six.
  final List<LookTopic> topics;

  /// The composer placeholder (`null`: the SDK's own).
  final LocalizedText? composerPlaceholder;

  /// Photos allowed.
  final bool allowsPhotos;

  /// Bug reports allowed.
  final bool allowsReports;

  /// Show author names.
  final bool showsNames;

  /// Show team avatars beside messages.
  final bool showsAvatars;

  /// Timestamps per group or per message.
  final ChatTimestamps timestamps;

  /// The reply expectation.
  final LocalizedText? replyExpectation;

  /// The assistant's display name.
  final String aiName;

  /// The team from the app's config.
  final List<TeamMember> team;

  /// An unpublished draft (test devices only).
  final bool isDraft;

  /// The remote revision; 0 when none.
  final int revision;

  /// The bubble radius in points (iOS) or dp (Android): 18, 12 or 6.
  final int bubbleRadius;
}

T _named<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

PingFrontColor _color(ColorMessage m) =>
    PingFrontColor.hex(m.light, m.dark) ??
    const PingFrontColor(Color(0xFF000000));

LocalizedText? _text(Map<String, String>? values) =>
    values == null ? null : LocalizedText(values);

/// Decodes a look.
ResolvedLook decodeLook(LookMessage m) => ResolvedLook(
  appName: m.appName,
  appIconUrl: m.appIconUrl,
  appIconPng: m.appIconPng,
  accent: _color(m.accent),
  onAccent: _color(m.onAccent),
  background: _color(m.background),
  teamBubble: _color(m.teamBubble),
  text: _color(m.text),
  muted: _color(m.muted),
  scheme: _named(ChatScheme.values, m.scheme, ChatScheme.auto),
  font: _named(ChatFont.values, m.font, ChatFont.system),
  corners: _named(ChatCorners.values, m.corners, ChatCorners.round),
  density: _named(ChatDensity.values, m.density, ChatDensity.comfortable),
  headerStyle: _named(
    ChatHeaderStyle.values,
    m.headerStyle,
    ChatHeaderStyle.person,
  ),
  headerMemberId: m.headerMemberId,
  headerTitle: _text(m.headerTitle),
  showsLocalTime: m.showsLocalTime,
  showsReplyExpectation: m.showsReplyExpectation,
  welcomeTitle: _text(m.welcomeTitle),
  welcomeBody: _text(m.welcomeBody),
  showsWelcomeFaces: m.showsWelcomeFaces,
  topics: [
    for (final t in m.topics)
      LookTopic(
        id: t.id,
        label: _text(t.label),
        symbol: _named(TopicSymbol.values, t.symbol, TopicSymbol.other),
        prefill: _text(t.prefill),
      ),
  ],
  composerPlaceholder: _text(m.composerPlaceholder),
  allowsPhotos: m.allowsPhotos,
  allowsReports: m.allowsReports,
  showsNames: m.showsNames,
  showsAvatars: m.showsAvatars,
  timestamps: _named(
    ChatTimestamps.values,
    m.timestamps,
    ChatTimestamps.grouped,
  ),
  replyExpectation: _text(m.replyExpectation),
  aiName: m.aiName,
  team: decodeTeamJson(m.teamJson),
  isDraft: m.isDraft,
  revision: m.revision,
  bubbleRadius: m.bubbleRadius,
);

/// An action a teammate ran from the inbox that your app has to do ("Fix it for them"), such as
/// extending a trial or repairing a sync.
///
/// Do the work once per [id], then call [complete] or [fail]. When [ackRequired] is true the receipt
/// line in the thread waits for [complete].
@immutable
class TeamAction {
  /// Creates an action (the plugin does this).
  const TeamAction({
    required this.id,
    required this.actionId,
    required this.name,
    required this.fields,
    required this.ackRequired,
    required this.createdAt,
    required this.expiresAt,
    required Future<void> Function(String? failure) answer,
    this.days,
    this.until,
  }) : _answer = answer; // ignore: prefer_initializing_formals, a private named parameter is not allowed

  /// This run's id. Do the work once per id.
  final String id;

  /// Which action: `extend_trial`, `grant_access`, or the id of one of your own actions.
  final String actionId;

  /// The action's name, as your team sees it.
  final String name;

  /// The values the teammate filled in, by field key.
  final Map<String, String> fields;

  /// Days, for `extend_trial` and `grant_access`.
  final int? days;

  /// The new end of access, for `extend_trial` and `grant_access`.
  final DateTime? until;

  /// True when the receipt line in the thread waits for [complete].
  final bool ackRequired;

  /// When the teammate ran it.
  final DateTime createdAt;

  /// After this the action expires and nothing is posted.
  final DateTime expiresAt;

  final Future<void> Function(String? failure) _answer;

  /// Tells the team the action is done; the receipt line posts in the thread. The first answer wins.
  Future<void> complete() => _answer(null);

  /// Tells the team the action could not be done. [message] is shown to the team, never to the person
  /// (at most 200 characters).
  Future<void> fail(String message) => _answer(message);
}
