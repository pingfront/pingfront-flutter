import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

import 'pingfront.dart' show PingFront;

/// How much the native SDK logs. Request paths at most, never bodies or tokens.
enum PingFrontLogLevel {
  /// Nothing, not even errors.
  off,

  /// Errors only.
  error,

  /// Problems and notable events (the default).
  info,

  /// Everything, including request paths.
  debug,
}

/// One native SDK log line, as [PingFrontOptions.logHandler] receives it.
///
/// The message is already redacted: ids, names, emails, URLs, tokens, server text and user input appear
/// as `<private>`, so it is safe to store and upload.
@immutable
class PingFrontLogEntry {
  /// Creates an entry.
  const PingFrontLogEntry({
    required this.level,
    required this.message,
    this.category,
  });

  /// [PingFrontLogLevel.error], [PingFrontLogLevel.info] or [PingFrontLogLevel.debug].
  final PingFrontLogLevel level;

  /// The redacted line.
  final String message;

  /// The SDK area (`session`, `network`, `live`, …), the same names on iOS and Android.
  final String? category;

  @override
  String toString() =>
      '[pingfront${category == null ? '' : '/$category'}] ${level.name}: $message';
}

/// Receives every native SDK log line at or above [PingFrontOptions.logLevel], on the platform thread.
/// Keep it fast; hand off to your logger.
typedef PingFrontLogHandler = void Function(PingFrontLogEntry entry);

/// iOS: the APNs environment of the push token.
enum PushEnvironment {
  /// Development builds.
  sandbox,

  /// TestFlight and App Store builds.
  production,
}

/// A color with a light and a dark value.
@immutable
class PingFrontColor {
  /// A color from two Flutter colors. Alpha is ignored.
  const PingFrontColor(this.light, [Color? dark]) : dark = dark ?? light;

  /// A color from `#RRGGBB` text, or `null` when the text is not a hex color.
  static PingFrontColor? hex(String light, [String? dark]) {
    final l = _parse(light);
    final d = dark == null ? l : _parse(dark);
    if (l == null || d == null) return null;
    return PingFrontColor(l, d);
  }

  /// The light mode value.
  final Color light;

  /// The dark mode value.
  final Color dark;

  /// `#RRGGBB` for [color], the format the native SDKs read.
  static String toHex(Color color) {
    String channel(double value) =>
        (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${channel(color.r)}${channel(color.g)}${channel(color.b)}'
        .toUpperCase();
  }

  static Color? _parse(String text) {
    final match = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(text.trim());
    if (match == null) return null;
    return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
  }

  @override
  bool operator ==(Object other) =>
      other is PingFrontColor &&
      toHex(other.light) == toHex(light) &&
      toHex(other.dark) == toHex(dark);

  @override
  int get hashCode => Object.hash(toHex(light), toHex(dark));

  @override
  String toString() => 'PingFrontColor(${toHex(light)}, ${toHex(dark)})';
}

/// Light, dark, or follow the system.
enum ChatScheme {
  /// Follow the system.
  auto,

  /// Always light.
  light,

  /// Always dark.
  dark,
}

/// The chat's font design.
enum ChatFont {
  /// The system font.
  system,

  /// The rounded system font.
  rounded,

  /// A serif.
  serif,
}

/// Bubble corners: round (18), soft (12) or square (6).
enum ChatCorners {
  /// 18 pt / dp.
  round,

  /// 12 pt / dp.
  soft,

  /// 6 pt / dp.
  square,
}

/// Spacing density.
enum ChatDensity {
  /// The default.
  comfortable,

  /// Tighter rows.
  compact,
}

/// When timestamps show.
enum ChatTimestamps {
  /// One caption per group of messages (the default).
  grouped,

  /// Under every message.
  always,
}

/// What the chat header shows.
enum ChatHeaderStyle {
  /// One teammate's face and name.
  person,

  /// Stacked team faces.
  team,

  /// The app icon and name.
  app,
}

/// Look values set in code.
///
/// Every field is optional. The look published in the dashboard wins, then these values, then what
/// the native SDK infers from the app, then its defaults.
@immutable
class ChatAppearance {
  /// Creates look values. Leave a field `null` to keep the default.
  const ChatAppearance({
    this.accent,
    this.background,
    this.teamBubble,
    this.scheme,
    this.font,
    this.corners,
    this.density,
    this.timestamps,
    this.headerStyle,
    this.headerTitle,
    this.headerMemberId,
    this.replyExpectation,
    this.showsReplyExpectation,
    this.showsLocalTime,
    this.showsAvatars,
    this.showsNames,
    this.showsWelcomeFaces,
    this.welcomeTitle,
    this.welcomeBody,
    this.composerPlaceholder,
    this.allowsPhotos,
    this.allowsReports,
    this.aiName,
    this.useDynamicColor,
  });

  /// The person's bubbles and buttons. Text on it is picked by contrast.
  final PingFrontColor? accent;

  /// The chat background.
  final PingFrontColor? background;

  /// The team bubble fill.
  final PingFrontColor? teamBubble;

  /// Force light or dark, or follow the system.
  final ChatScheme? scheme;

  /// System, rounded or serif.
  final ChatFont? font;

  /// Bubble corners.
  final ChatCorners? corners;

  /// Spacing density.
  final ChatDensity? density;

  /// Timestamps per group or per message.
  final ChatTimestamps? timestamps;

  /// The header style.
  final ChatHeaderStyle? headerStyle;

  /// The header title for the team and app styles.
  final String? headerTitle;

  /// Which teammate the person header shows.
  final String? headerMemberId;

  /// For example "Usually replies within a few hours".
  final String? replyExpectation;

  /// Show the reply expectation line.
  final bool? showsReplyExpectation;

  /// Show the teammate's local time.
  final bool? showsLocalTime;

  /// Show team avatars beside messages.
  final bool? showsAvatars;

  /// Show author names.
  final bool? showsNames;

  /// Show team faces on the welcome screen.
  final bool? showsWelcomeFaces;

  /// The welcome title.
  final String? welcomeTitle;

  /// The welcome body.
  final String? welcomeBody;

  /// The composer placeholder.
  final String? composerPlaceholder;

  /// Allow photos.
  final bool? allowsPhotos;

  /// Allow bug reports.
  final bool? allowsReports;

  /// The assistant's display name.
  final String? aiName;

  /// Android 12+ only: Material You colors. Ignored on iOS.
  final bool? useDynamicColor;
}

/// The symbol on a topic chip.
enum TopicSymbol {
  /// Billing.
  billing,

  /// A bug.
  bug,

  /// An idea.
  idea,

  /// A question.
  question,

  /// The account.
  account,

  /// Feedback.
  feedback,

  /// A gift.
  gift,

  /// Restoring purchases.
  restore,

  /// Privacy.
  privacy,

  /// Anything else.
  other,
}

/// A screen of your app that the team's saved links can open (https://pingfront.sh/docs/offers#saved-links). Register them
/// with `PingFront.registerScreens`; a link card for one goes to `PingFront.onScreen`.
@immutable
class AppScreen {
  /// A screen. [id] is your own route id, such as `settings.sound` or `plans/yearly`:
  /// `^[A-Za-z0-9][A-Za-z0-9_./:-]{0,99}$`.
  const AppScreen(this.id, {this.title});

  /// Your route id for the screen.
  final String id;

  /// What the team sees in the dashboard ("Sound settings"), at most 60 characters. Never shown to the person.
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is AppScreen && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'AppScreen($id, $title)';
}

/// A topic chip on the welcome screen, or the topic [PingFront.openChat] starts with.
///
/// Use a preset or the constructor. With a [prefill], tapping the chip fills the composer; without
/// one it starts the thread on that topic.
@immutable
class ChatTopic {
  /// A custom topic. [id] is 1 to 32 characters of `a-z`, `0-9`, `_` or `-`.
  const ChatTopic(
    this.id, {
    this.label,
    this.symbol = TopicSymbol.other,
    this.prefill,
  });

  /// "Ask about billing".
  static const ChatTopic billing = ChatTopic(
    'billing',
    symbol: TopicSymbol.billing,
  );

  /// "Report a bug".
  static const ChatTopic bug = ChatTopic('bug', symbol: TopicSymbol.bug);

  /// "Share an idea".
  static const ChatTopic idea = ChatTopic('idea', symbol: TopicSymbol.idea);

  /// "Ask a question".
  static const ChatTopic question = ChatTopic(
    'question',
    symbol: TopicSymbol.question,
  );

  /// "Get help with my account".
  static const ChatTopic account = ChatTopic(
    'account',
    symbol: TopicSymbol.account,
  );

  /// "Send feedback".
  static const ChatTopic feedback = ChatTopic(
    'feedback',
    symbol: TopicSymbol.feedback,
  );

  /// "Ask about gifts".
  static const ChatTopic gift = ChatTopic('gift', symbol: TopicSymbol.gift);

  /// "Restore purchases".
  static const ChatTopic restore = ChatTopic(
    'restore',
    symbol: TopicSymbol.restore,
  );

  /// "Ask about privacy".
  static const ChatTopic privacy = ChatTopic(
    'privacy',
    symbol: TopicSymbol.privacy,
  );

  /// Stable id.
  final String id;

  /// The label. `null` uses the native SDK's translated label for a preset id.
  final String? label;

  /// The chip symbol.
  final TopicSymbol symbol;

  /// Text put into the composer when the chip is tapped.
  final String? prefill;

  @override
  bool operator ==(Object other) =>
      other is ChatTopic &&
      other.id == id &&
      other.label == label &&
      other.symbol == symbol &&
      other.prefill == prefill;

  @override
  int get hashCode => Object.hash(id, label, symbol, prefill);
}

/// An optional native module.
@immutable
sealed class PingFrontModule {
  const PingFrontModule();

  /// Push helpers. iOS: tap routing and foreground presentation (`.push`). Android: FCM through
  /// the `pingfront-push` artifact, which your app adds to its Gradle dependencies.
  const factory PingFrontModule.push() = PushModule;

  /// Shake to report, a screenshot with markup, the log tail and device state.
  const factory PingFrontModule.reports({bool shakeToReport, bool logTail}) =
      ReportsModule;

  /// The store: StoreKit 2 on iOS, Google Play Billing on Android (the `pingfront-billing`
  /// artifact). [products] are the product ids the team can offer in offer cards.
  const factory PingFrontModule.store({List<String> products}) = StoreModule;
}

/// A vendor adapter (RevenueCat, Superwall, Adapty) from its add-on package, such as
/// `pingfront_revenuecat`. Apps use the add-on's own API (`PingFrontRevenueCat.module()`); the add-on
/// builds this, and its native code turns [options] into the native adapter.
final class AdapterModule extends PingFrontModule {
  /// Creates the module. [id] names the add-on's native factory (`revenuecat`, `superwall`, `adapty`).
  const AdapterModule(this.id, [this.options = const {}]);

  /// The adapter id.
  final String id;

  /// Options the add-on's native factory reads (strings, numbers, booleans, lists and maps of them).
  final Map<String, Object?> options;
}

/// See [PingFrontModule.push].
final class PushModule extends PingFrontModule {
  /// Creates the module.
  const PushModule();
}

/// See [PingFrontModule.reports].
final class ReportsModule extends PingFrontModule {
  /// Creates the module.
  const ReportsModule({this.shakeToReport = true, this.logTail = true});

  /// Open the report when the person shakes the device.
  final bool shakeToReport;

  /// Attach the last minutes of this app's log.
  final bool logTail;
}

/// See [PingFrontModule.store].
final class StoreModule extends PingFrontModule {
  /// Creates the module.
  const StoreModule({this.products = const []});

  /// Product ids the team can offer.
  final List<String> products;
}

/// Options for [PingFront.configure]. Every option has a default.
@immutable
class PingFrontOptions {
  /// Creates options.
  const PingFrontOptions({
    this.appearance = const ChatAppearance(),
    this.topics,
    this.modules = const [],
    this.logLevel = PingFrontLogLevel.info,
    this.baseUrl,
    this.presentsChatForMoments = true,
    this.closesChatForOffers = true,
    this.language,
    this.logHandler,
    this.pushEnvironment,
  });

  /// Look values set in code.
  final ChatAppearance appearance;

  /// Topic chips on the welcome screen, up to six. `null` keeps the defaults.
  final List<ChatTopic>? topics;

  /// Optional native modules.
  final List<PingFrontModule> modules;

  /// How much the native SDK logs.
  final PingFrontLogLevel logLevel;

  /// The API base URL, for local development. `null` is production.
  final String? baseUrl;

  /// Present the chat when the server answers a moment with `open`.
  final bool presentsChatForMoments;

  /// Close the native chat before [PingFront.onOffer] runs, so a paywall you push as a Flutter
  /// route is never hidden behind it. Turn it off only when `onOffer` presents native UI that
  /// shows above the chat on its own (for example a vendor paywall).
  final bool closesChatForOffers;

  /// The chat's language when your app has its own language picker: a BCP 47 tag such as `de` or
  /// `pt-BR`. `null` follows the app's and the system's language. Change it later with
  /// [PingFront.setLanguage].
  final String? language;

  /// Routes native SDK log lines into your own logger, in addition to the platform log. Lines are
  /// already redacted. `null` (the default) forwards nothing.
  final PingFrontLogHandler? logHandler;

  /// iOS: the APNs environment of the push token. `null` picks sandbox in debug builds, production
  /// otherwise. Ignored on Android.
  final PushEnvironment? pushEnvironment;
}

/// One purchasable product in an [OfferSlot].
@immutable
class OfferProduct {
  /// Creates a product entry.
  const OfferProduct({
    required this.id,
    required this.price,
    this.period,
    this.trial,
  });

  /// The store product id.
  final String id;

  /// The localized display price, for example "€4.99".
  final String price;

  /// ISO-8601 period such as "P1M".
  final String? period;

  /// ISO-8601 trial period such as "P1W".
  final String? trial;
}

/// The flavour of an offer.
enum OfferKind {
  /// A regular offer.
  standard,

  /// A discount.
  discount,

  /// A win-back offer.
  winback,
}

/// An offer the app can show, reported with [PingFront.setOffers] so the team (and plays) can
/// send offer cards for it.
@immutable
class OfferSlot {
  /// Creates a slot. [id] is 1 to 64 characters of `A-Z a-z 0-9 _ . -`; [title] at most 60.
  const OfferSlot({
    required this.id,
    required this.title,
    this.kind = OfferKind.standard,
    this.isAvailable = true,
    this.products = const [],
    this.source,
  });

  /// Stable id referenced by offer cards.
  final String id;

  /// Short title.
  final String title;

  /// The flavour.
  final OfferKind kind;

  /// Whether the app can show it right now.
  final bool isAvailable;

  /// Products inside the offer.
  final List<OfferProduct> products;

  /// Where the paywall is built (`app`, `storekit`, `play`, `revenuecat`, …). Set by the native
  /// side on slots it reports; leave it `null` for your own.
  final String? source;
}

/// A store offer an offer card redeems on top of opening the paywall.
@immutable
class StoreOffer {
  /// Creates a store offer.
  const StoreOffer({
    required this.kind,
    required this.id,
    this.productId,
    this.basePlanId,
    this.offerId,
  });

  /// `promotional`, `winback`, `code`, `intro`, a Play offer kind, or a kind this version does not
  /// know (kept verbatim).
  final String kind;

  /// The offer identifier.
  final String id;

  /// The product the offer applies to.
  final String? productId;

  /// Google Play: the base plan.
  final String? basePlanId;

  /// Google Play: the offer within the base plan.
  final String? offerId;
}

/// An offer card the person tapped.
@immutable
class OfferRequest {
  /// Creates a request.
  const OfferRequest({
    required this.offerId,
    required this.cardId,
    required this.messageId,
    this.slot,
    this.storeOffer,
  });

  /// The [OfferSlot.id] the card names.
  final String offerId;

  /// The card id.
  final String cardId;

  /// The id of the message that carries the card.
  final String messageId;

  /// The matching slot, if the app or a module reported one.
  final OfferSlot? slot;

  /// The store offer the card redeems, if any.
  final StoreOffer? storeOffer;
}

/// Subscription lifecycle states.
enum EntitlementState {
  /// No subscription.
  none,

  /// In a trial.
  trial,

  /// Active.
  active,

  /// In a billing grace period.
  grace,

  /// The store retries a failed payment.
  billingRetry,

  /// Cancelled; access until it expires.
  cancelled,

  /// Expired.
  expired,

  /// Bought for life.
  lifetime,

  /// A state this version does not know.
  unknown,
}

/// The person's subscription state, for [PingFront.setEntitlement].
@immutable
class Entitlement {
  /// Creates an entitlement.
  const Entitlement({
    required this.state,
    this.productId,
    this.renewsAt,
    this.expiresAt,
    this.gracePeriodEndsAt,
    this.source = 'app',
  });

  /// The current state.
  final EntitlementState state;

  /// The product that grants it.
  final String? productId;

  /// When it renews.
  final DateTime? renewsAt;

  /// Android: when access ends or ended. iOS reads [renewsAt] only.
  final DateTime? expiresAt;

  /// Android: for grace and billing retry, the day access ends unless the payment is fixed.
  final DateTime? gracePeriodEndsAt;

  /// Which system reported it. `app` for your own code.
  final String? source;
}

/// Identity levels.
enum PersonLevel {
  /// Anonymous.
  guest,

  /// Named by the app, not verified.
  named,

  /// Verified with an identity token: one thread across devices.
  verified,

  /// A level this version does not know.
  unknown,
}

/// The person this install belongs to, once a session exists.
@immutable
class PersonSummary {
  /// Creates a summary.
  const PersonSummary({required this.id, required this.level, this.name});

  /// The server id.
  final String id;

  /// Guest, named or verified.
  final PersonLevel level;

  /// The display name, if known.
  final String? name;
}

/// What kind of configuration problem.
enum ConfigurationProblemKind {
  /// The key failed the offline check.
  invalidKey,

  /// No key was passed.
  missingKey,

  /// The server does not know the key.
  unknownKey,

  /// The app is paused in the dashboard.
  appPaused,

  /// Another option is wrong.
  option,

  /// iOS: the Keychain refused to store the install.
  keychain,

  /// An offer card arrived but nothing can show offers.
  offerHandler,

  /// A kind this version does not know.
  unknown,
}

/// A configuration problem. Debug builds also show it in a red banner in the chat.
@immutable
class ConfigurationProblem {
  /// Creates a problem.
  const ConfigurationProblem({
    required this.kind,
    required this.message,
    required this.disablesSdk,
  });

  /// What kind of problem.
  final ConfigurationProblemKind kind;

  /// The exact problem and what to do, in plain words.
  final String message;

  /// True when the SDK disabled itself because of it.
  final bool disablesSdk;

  @override
  String toString() => 'ConfigurationProblem(${kind.name}): $message';
}

/// A snapshot of the native SDK's state.
@immutable
class PingFrontState {
  /// Creates a snapshot.
  const PingFrontState({
    required this.isConfigured,
    required this.unreadCount,
    required this.isChatVisible,
    required this.isTestDevice,
    this.person,
    this.configurationProblem,
  });

  /// True after a successful [PingFront.configure].
  final bool isConfigured;

  /// Unread team messages.
  final int unreadCount;

  /// True while the chat is on screen.
  final bool isChatVisible;

  /// True when the dashboard marked this device as a test device.
  final bool isTestDevice;

  /// The person, once a session exists.
  final PersonSummary? person;

  /// The problem found at configure time, if any.
  final ConfigurationProblem? configurationProblem;
}
