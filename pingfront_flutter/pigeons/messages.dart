// The wire between Dart and the native SDKs. Regenerate with `tool/pigeon.sh` after any change.
//
// These are transport shapes, not the public API: `lib/src/models.dart` holds the Dart types apps use,
// and `lib/src/codec.dart` maps between the two. Enum-like values travel as strings so a value one side
// does not know never fails to decode; each side maps unknown strings to its "unknown" case.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/dev/pingfront/flutter/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.pingfront.flutter',
      errorClassName: 'BridgeError',
    ),
    swiftOut:
        'ios/pingfront_flutter/Sources/pingfront_flutter/Messages.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'BridgeError'),
    dartPackageName: 'pingfront_flutter',
  ),
)
/// A color with light and dark values, as `#RRGGBB`.
class ColorMessage {
  ColorMessage({required this.light, required this.dark});
  String light;
  String dark;
}

/// A topic chip. `label` and `prefill` are single-language; `symbol` is a `TopicSymbol` name.
class TopicMessage {
  TopicMessage({required this.id, required this.symbol});
  String id;
  String? label;
  String symbol;
  String? prefill;
}

/// `ChatAppearance`: every field optional, enum values as their lowercase names.
class AppearanceMessage {
  ColorMessage? accent;
  ColorMessage? background;
  ColorMessage? teamBubble;
  String? scheme;
  String? font;
  String? corners;
  String? density;
  String? timestamps;
  String? headerStyle;
  String? headerTitle;
  String? headerMemberId;
  String? replyExpectation;
  bool? showsReplyExpectation;
  bool? showsLocalTime;
  bool? showsAvatars;
  bool? showsNames;
  bool? showsWelcomeFaces;
  String? welcomeTitle;
  String? welcomeBody;
  String? composerPlaceholder;
  bool? allowsPhotos;
  bool? allowsReports;
  String? aiName;
  bool? useDynamicColor;
}

/// An optional native module: `push`, `reports`, `store`, or a vendor adapter (`revenuecat`, `superwall`,
/// `adapty`) whose add-on package reads `options`.
class ModuleMessage {
  ModuleMessage({required this.id});
  String id;
  List<String>? products;
  bool? shakeToReport;
  bool? logTail;

  /// A vendor adapter's options, as its add-on package's native factory reads them.
  Map<String, Object?>? options;
}

/// The native `SetupCheckResult`: `code` is null when it passed.
class SelfCheckMessage {
  SelfCheckMessage({required this.passed, required this.line});
  bool passed;
  String? code;
  String line;
}

class ConfigureRequest {
  ConfigureRequest({
    required this.appearance,
    required this.modules,
    required this.logLevel,
    required this.presentsChatForMoments,
    required this.handlesOffers,
    required this.closesChatForOffers,
    required this.handlesLinks,
    required this.wrapperVersion,
    required this.forwardsLogs,
  });

  /// Null reads the key from Info.plist (`PingFrontAppKey`) or the manifest (`pingfront.app_key`).
  String? appKey;
  String? baseUrl;
  String logLevel;
  bool presentsChatForMoments;
  List<TopicMessage>? topics;
  AppearanceMessage appearance;
  List<ModuleMessage> modules;
  bool handlesOffers;
  bool closesChatForOffers;
  bool handlesLinks;

  /// This plugin's version: the native SDKs send `PF-Wrapper: flutter/<wrapperVersion>`.
  String wrapperVersion;

  /// A BCP 47 tag for the chat's language, or null to follow the app and system.
  String? language;

  /// True when Dart set a log handler: native then sends every SDK log line to `onLog`.
  bool forwardsLogs;

  /// iOS: `sandbox` or `production` for push tokens; null picks by build type. Ignored on Android.
  String? pushEnvironment;
}

class OfferProductMessage {
  OfferProductMessage({required this.id, required this.price});
  String id;
  String price;
  String? period;
  String? trial;
}

class OfferSlotMessage {
  OfferSlotMessage({
    required this.id,
    required this.title,
    required this.kind,
    required this.available,
    required this.products,
  });
  String id;
  String title;
  String kind;
  bool available;
  List<OfferProductMessage> products;
  String? source;
}

class StoreOfferMessage {
  StoreOfferMessage({required this.kind, required this.id});
  String kind;
  String id;
  String? productId;
  String? basePlanId;
  String? offerId;
}

class OfferRequestMessage {
  OfferRequestMessage({
    required this.offerId,
    required this.cardId,
    required this.messageId,
  });
  String offerId;
  String cardId;
  String messageId;
  OfferSlotMessage? slot;
  StoreOfferMessage? storeOffer;
}

/// Dates are milliseconds since the epoch, UTC.
class EntitlementMessage {
  EntitlementMessage({required this.state});
  String state;
  String? productId;
  int? renewsAtMs;
  int? expiresAtMs;
  int? gracePeriodEndsAtMs;
  String? source;
}

class PersonMessage {
  PersonMessage({required this.id, required this.level});
  String id;
  String level;
  String? name;
}

class ProblemMessage {
  ProblemMessage({
    required this.kind,
    required this.message,
    required this.disablesSdk,
  });
  String kind;
  String message;
  bool disablesSdk;
}

/// `kind` is a `MomentResult` name; `errorCode` and `errorMessage` are set for `failed`.
class MomentResultMessage {
  MomentResultMessage({required this.kind});
  String kind;
  bool? presented;
  String? errorCode;
  String? errorMessage;
}

/// A snapshot of the SDK's observable state.
class StateMessage {
  StateMessage({
    required this.isConfigured,
    required this.unreadCount,
    required this.isChatVisible,
    required this.isTestDevice,
  });
  bool isConfigured;
  int unreadCount;
  bool isChatVisible;
  bool isTestDevice;
  PersonMessage? person;
  ProblemMessage? configurationProblem;
}

/// One SDK log line. `category` is the SDK area (`session`, `network`, …), on both platforms.
class LogEntryMessage {
  LogEntryMessage({required this.level, required this.message});
  String level;
  String message;
  String? category;
}

/// A topic of the resolved look. Texts are per language (`default` plus tags), as the dashboard publishes them.
class LookTopicMessage {
  LookTopicMessage({required this.id, required this.symbol});
  String id;
  Map<String, String>? label;
  String symbol;
  Map<String, String>? prefill;
}

/// The resolved chat look. Enum values as their Dart names; localized texts as `{tag: text}` maps.
class LookMessage {
  LookMessage({
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
    required this.teamJson,
    required this.isDraft,
    required this.revision,
    required this.bubbleRadius,
  });
  String appName;
  String? appIconUrl;
  Uint8List? appIconPng;
  ColorMessage accent;
  ColorMessage onAccent;
  ColorMessage background;
  ColorMessage teamBubble;
  ColorMessage text;
  ColorMessage muted;
  String scheme;
  String font;
  String corners;
  String density;
  String headerStyle;
  String? headerMemberId;
  Map<String, String>? headerTitle;
  bool showsLocalTime;
  bool showsReplyExpectation;
  Map<String, String>? welcomeTitle;
  Map<String, String>? welcomeBody;
  bool showsWelcomeFaces;
  List<LookTopicMessage> topics;
  Map<String, String>? composerPlaceholder;
  bool allowsPhotos;
  bool allowsReports;
  bool showsNames;
  bool showsAvatars;
  String timestamps;
  Map<String, String>? replyExpectation;
  String aiName;

  /// The team, as the wire's `TeamMember` JSON array.
  String teamJson;
  bool isDraft;
  int revision;
  int bubbleRadius;
}

/// A team action ("Fix it for them"). Dates are milliseconds since the epoch, UTC.
class TeamActionMessage {
  TeamActionMessage({
    required this.id,
    required this.actionId,
    required this.name,
    required this.fields,
    required this.ackRequired,
    required this.createdAtMs,
    required this.expiresAtMs,
  });
  String id;
  String actionId;
  String name;
  Map<String, String> fields;
  int? days;
  int? untilMs;
  bool ackRequired;
  int createdAtMs;
  int expiresAtMs;
}

class PendingPhotoMessage {
  PendingPhotoMessage({
    required this.width,
    required this.height,
    required this.bytes,
    required this.sha256,
  });
  int width;
  int height;
  int bytes;
  String sha256;
  String? attachmentId;
}

/// A message the person wrote that the server has not acknowledged. `state`: `queued`, `sending`, `failed`.
class PendingMessageMessage {
  PendingMessageMessage({
    required this.clientId,
    required this.photos,
    required this.createdAtMs,
    required this.attempts,
    required this.state,
  });
  String clientId;
  String? text;
  List<PendingPhotoMessage> photos;
  int createdAtMs;
  int attempts;
  String state;
  String? failure;

  /// Why a closed policy holds it (`app_paused`, `verification_required`): the wire code, or null.
  String? heldFor;
}

/// One timeline row. `contentKind` is `message` (contentId: the message id) or `pending` (the client id).
class TimelineItemMessage {
  TimelineItemMessage({
    required this.id,
    required this.contentKind,
    required this.contentId,
    required this.side,
    required this.startsGroup,
    required this.endsGroup,
    required this.startsPing,
    required this.isAi,
    required this.dateMs,
    required this.startsTimeSection,
  });
  String id;
  String contentKind;
  String contentId;
  String side;
  bool startsGroup;
  bool endsGroup;
  bool startsPing;
  bool isAi;
  String? authorName;
  int dateMs;
  bool startsTimeSection;
}

/// A snapshot of `PingFront.conversation`. Messages and the team travel as the wire's JSON, so Dart decodes
/// them with the same unknown-safe rules as every SDK.
class ConversationMessage {
  ConversationMessage({
    required this.phase,
    required this.messagesJson,
    required this.pending,
    required this.timeline,
    required this.hasOlder,
    required this.isLoadingOlder,
    required this.teamJson,
    required this.canSend,
    required this.status,
    required this.live,
    required this.liveOffline,
    required this.teamReadSeq,
    required this.isOffline,
    required this.isServerUnreachable,
    required this.draft,
    required this.coolingDown,
    required this.awaitingApproval,
  });

  /// `idle`, `loading`, `ready` or `failed`.
  String phase;

  /// For `failed`: the error code (iOS), or `network` when the device looked offline (Android).
  String? failureCode;
  String messagesJson;
  List<PendingMessageMessage> pending;
  List<TimelineItemMessage> timeline;
  bool hasOlder;
  bool isLoadingOlder;
  String teamJson;
  String? replyExpectation;
  bool canSend;

  /// Why sending is off (`blocked`, `app_paused`, `verification_required`, or a newer code).
  String? closedReason;

  /// `open`, `resolved` or `unknown`.
  String status;

  /// Set while someone types: their name, and whether it is the assistant.
  bool? typingIsAi;
  String? typingName;

  /// `stopped`, `connecting`, `live` or `waiting`.
  String live;
  int? liveRetryInMs;
  bool liveOffline;
  int teamReadSeq;
  bool isOffline;

  /// Of `isOffline`: the device has a network, but the last request could not reach the service.
  bool isServerUnreachable;
  String draft;
  String? composerInsertion;

  /// Rate-limit scopes cooling down right now.
  List<String> coolingDown;

  /// iOS: offer cards whose purchase waits for approval.
  List<String> awaitingApproval;
}

/// One SDK event. `type` names it; `data` carries its fields. Types the Dart side does not know
/// become `PingFrontEvent.unknown`, so a newer native SDK never breaks an older plugin.
/// A screen the app registered for saved links (https://pingfront.sh/docs/offers#saved-links).
class AppScreenMessage {
  AppScreenMessage({required this.id, this.title});
  String id;
  String? title;
}

/// A link card's screen, for the Dart `onScreen` handler.
class LinkScreenMessage {
  LinkScreenMessage({required this.id, required this.params});
  String id;
  Map<String, String> params;
}

class EventMessage {
  EventMessage({required this.type, required this.data});
  String type;
  Map<String, Object?> data;
}

// Every host method is `@async`: Swift runs it on the main actor, where the native SDK lives, and
// Kotlin on the main thread. Results come back once the native call finished.
@HostApi()
abstract class PingFrontHostApi {
  @async
  void configure(ConfigureRequest request);

  /// Updates which Dart callbacks are set, so native only forwards what Dart handles.
  @async
  void setHandlers(
    bool handlesOffers,
    bool closesChatForOffers,
    bool handlesLinks,
  );

  @async
  StateMessage state();

  @async
  void identify(String userId, String? name, String? email);

  @async
  void identifyWithToken(String token);

  @async
  void setTraits(Map<String, String> traits);

  @async
  void setEntitlement(EntitlementMessage entitlement);

  @async
  void setOffers(List<OfferSlotMessage> offers);

  @async
  void logout();

  @async
  void eraseMyData();

  /// Everything the server holds about the person, as the JSON text it sent.
  @async
  String exportMyData();

  @async
  void prepare();

  @async
  void openChat(TopicMessage? topic);

  /// Closes the chat and completes once it is off screen (or after a short timeout).
  @async
  void closeChat();

  @async
  MomentResultMessage moment(String name, Map<String, Object> props);

  @async
  void setPushToken(String? token);

  /// `opened` is true for a notification tap, false for one received while the app runs.
  @async
  bool handlePush(Map<String, Object?> payload, bool opened);

  @async
  bool isPingFrontPush(Map<String, Object?> payload);

  @async
  void openReport(String? prefill);

  /// Opens the chat or the bug report from a chat link (https://pingfront.sh/docs/chat-links). True only when it was one.
  @async
  bool handleUrl(String url);

  @async
  void reportBug(String text, Uint8List? screenshot);

  /// The native SDK's `selfCheck()`: sends the setup check message, waits for the server and returns its result.
  @async
  SelfCheckMessage selfCheck();

  /// The chat's language (a BCP 47 tag), or null to follow the app and system.
  @async
  void setLanguage(String? tag);

  @async
  String? language();

  /// The person's store account token (iOS: a UUID string; Android: Play's `obfuscatedAccountId`), once a
  /// session exists.
  @async
  String? storeAccountToken();

  /// Whether the dashboard turned on the app icon badge (`features.appBadge`), on both platforms.
  @async
  bool usesAppBadge();

  /// iOS: asks for notification permission and registers for remote notifications. Android: asks for
  /// `POST_NOTIFICATIONS` on Android 13+ (granted earlier).
  @async
  bool requestPushAuthorization();

  /// iOS: a silent push in the background (`newData`, `noData`, `failed`), or null when it isn't ours.
  /// Android: null (the push module handles data messages).
  @async
  String? handleBackgroundPush(Map<String, Object?> payload);

  /// The resolved chat look.
  @async
  LookMessage look();

  /// Answers a team action the app did.
  @async
  void completeTeamAction(String id);

  @async
  void failTeamAction(String id, String message);

  // Conversation: build your own chat UI.

  @async
  ConversationMessage conversationState();

  @async
  void conversationSend(String text, List<Uint8List> photos);

  @async
  void conversationRetry(String clientId);

  @async
  void conversationDiscard(String clientId);

  @async
  void conversationLoadOlder();

  @async
  void conversationChoose(String messageId, String cardId, String optionId);

  @async
  void conversationRate(String messageId, String cardId, int rating);

  @async
  void conversationOpenCard(String messageId, String cardId);

  @async
  void conversationSetTyping(bool typing);

  /// Returns when the reload has finished (loaded or failed).
  @async
  void conversationReload();

  /// Marks the messages on screen as read (a custom chat UI; the built-in chat does it by itself).
  @async
  void conversationMarkRead();

  @async
  void conversationSetDraft(String text);

  /// Clears `composerInsertion` once the UI put it in the composer.
  @async
  void conversationConsumeInsertion();

  /// The JPEG bytes of a photo still waiting to be sent.
  @async
  Uint8List? conversationPhotoData(String clientId, String sha256);

  /// A fresh URL for an image whose short-lived URL expired.
  @async
  String? conversationRefreshedImageUrl(String messageId, String attachmentId);

  /// Milliseconds left on a rate-limit cooldown, or null.
  @async
  int? conversationCooldownRemaining(String scope);

  /// The app's screens for saved links; checked natively (a bad id fails in a debug build, is dropped in release).
  @async
  void registerScreens(List<AppScreenMessage> screens);

  /// While enabled, a link card for a registered screen goes to the Flutter API's `onScreen`.
  @async
  void setScreenHandler(bool enabled);

  /// Android: the safe-area padding (logical pixels, which are dp) that no Flutter ancestor consumed at an
  /// embedded chat's position (`MediaQuery.paddingOf`), for `PingFrontChat(windowInsets:)`. Flutter keeps the
  /// view clear of the keyboard itself. iOS derives the safe area from the view's window.
  @async
  void setChatViewPadding(
    int viewId,
    double left,
    double top,
    double right,
    double bottom,
  );
}

@FlutterApi()
abstract class PingFrontFlutterApi {
  /// An offer card was tapped. When `closesChatForOffers` is on, the chat is already closed.
  @async
  void onOffer(OfferRequestMessage request);

  /// A link was tapped in the chat. Return true when Dart handled it.
  @async
  bool onLink(String url);

  /// A link card for a screen the app registered was tapped. Return true when Dart opened the screen.
  @async
  bool onScreen(LinkScreenMessage screen);

  /// One SDK log line, when Dart set a log handler. Always called on the platform thread.
  void onLog(LogEntryMessage entry);

  /// An embedded chat view drew its first frame, so its placeholder can go.
  void onChatViewShown(int viewId);
}

@EventChannelApi()
abstract class PingFrontStreamApi {
  EventMessage events();

  /// The current unread count first, then every change.
  int unreadCounts();

  /// Team actions: those not answered yet first, then each new one once.
  TeamActionMessage teamActions();

  /// The conversation: the current snapshot first, then every change.
  ConversationMessage conversationStates();

  /// The resolved look: the current value first, then every change.
  LookMessage looks();
}
