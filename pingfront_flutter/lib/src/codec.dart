// Maps the public Dart types to the Pigeon transport shapes and back. Strings the plugin does not
// know always map to an "unknown" value, never to an exception.
import 'messages.g.dart';
import 'models.dart';
import 'results.dart';

/// Wire names of the native modules.
abstract final class ModuleIds {
  /// Push.
  static const String push = 'push';

  /// Bug reports.
  static const String reports = 'reports';

  /// StoreKit 2 / Play Billing.
  static const String store = 'store';
}

T _byName<T extends Enum>(List<T> values, String? name, T fallback) {
  if (name == null) return fallback;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

ColorMessage? _color(PingFrontColor? color) => color == null
    ? null
    : ColorMessage(
        light: PingFrontColor.toHex(color.light),
        dark: PingFrontColor.toHex(color.dark),
      );

/// Encodes a topic.
TopicMessage encodeTopic(ChatTopic topic) => TopicMessage(
  id: topic.id,
  label: topic.label,
  symbol: topic.symbol.name,
  prefill: topic.prefill,
);

/// Encodes look values.
AppearanceMessage encodeAppearance(ChatAppearance a) => AppearanceMessage(
  accent: _color(a.accent),
  background: _color(a.background),
  teamBubble: _color(a.teamBubble),
  scheme: a.scheme?.name,
  font: a.font?.name,
  corners: a.corners?.name,
  density: a.density?.name,
  timestamps: a.timestamps?.name,
  headerStyle: a.headerStyle?.name,
  headerTitle: a.headerTitle,
  headerMemberId: a.headerMemberId,
  replyExpectation: a.replyExpectation,
  showsReplyExpectation: a.showsReplyExpectation,
  showsLocalTime: a.showsLocalTime,
  showsAvatars: a.showsAvatars,
  showsNames: a.showsNames,
  showsWelcomeFaces: a.showsWelcomeFaces,
  welcomeTitle: a.welcomeTitle,
  welcomeBody: a.welcomeBody,
  composerPlaceholder: a.composerPlaceholder,
  allowsPhotos: a.allowsPhotos,
  allowsReports: a.allowsReports,
  aiName: a.aiName,
  useDynamicColor: a.useDynamicColor,
);

/// Encodes a module.
ModuleMessage encodeModule(PingFrontModule module) => switch (module) {
  PushModule() => ModuleMessage(id: ModuleIds.push),
  ReportsModule(:final shakeToReport, :final logTail) => ModuleMessage(
    id: ModuleIds.reports,
    shakeToReport: shakeToReport,
    logTail: logTail,
  ),
  StoreModule(:final products) => ModuleMessage(
    id: ModuleIds.store,
    products: products,
  ),
  AdapterModule(:final id, :final options) => ModuleMessage(
    id: id,
    options: options,
  ),
};

/// Encodes the configure call.
ConfigureRequest encodeConfigure(
  String? appKey,
  PingFrontOptions options, {
  required bool handlesOffers,
  required bool handlesLinks,
}) => ConfigureRequest(
  appKey: appKey,
  baseUrl: options.baseUrl,
  logLevel: options.logLevel.name,
  presentsChatForMoments: options.presentsChatForMoments,
  topics: options.topics?.map(encodeTopic).toList(),
  appearance: encodeAppearance(options.appearance),
  modules: options.modules.map(encodeModule).toList(),
  handlesOffers: handlesOffers,
  closesChatForOffers: options.closesChatForOffers,
  handlesLinks: handlesLinks,
  wrapperVersion: pluginVersion,
  language: options.language,
  forwardsLogs: options.logHandler != null,
  pushEnvironment: options.pushEnvironment?.name,
);

/// Decodes a log line.
PingFrontLogEntry decodeLogEntry(LogEntryMessage m) => PingFrontLogEntry(
  level: _byName(PingFrontLogLevel.values, m.level, PingFrontLogLevel.info),
  message: m.message,
  category: m.category,
);

/// This plugin's version, sent by the native SDKs as `PF-Wrapper: flutter/<version>`. Kept equal to
/// pubspec.yaml (test/wrapper_test.dart).
const String pluginVersion = '1.0.0';

/// Encodes an offer slot.
OfferSlotMessage encodeSlot(OfferSlot slot) => OfferSlotMessage(
  id: slot.id,
  title: slot.title,
  kind: slot.kind.name,
  available: slot.isAvailable,
  products: [
    for (final p in slot.products)
      OfferProductMessage(
        id: p.id,
        price: p.price,
        period: p.period,
        trial: p.trial,
      ),
  ],
  source: slot.source,
);

/// Decodes an offer slot.
OfferSlot decodeSlot(OfferSlotMessage m) => OfferSlot(
  id: m.id,
  title: m.title,
  kind: _byName(OfferKind.values, m.kind, OfferKind.standard),
  isAvailable: m.available,
  products: [
    for (final p in m.products)
      OfferProduct(id: p.id, price: p.price, period: p.period, trial: p.trial),
  ],
  source: m.source,
);

/// Decodes an offer request.
OfferRequest decodeOfferRequest(OfferRequestMessage m) => OfferRequest(
  offerId: m.offerId,
  cardId: m.cardId,
  messageId: m.messageId,
  slot: m.slot == null ? null : decodeSlot(m.slot!),
  storeOffer: m.storeOffer == null
      ? null
      : StoreOffer(
          kind: m.storeOffer!.kind,
          id: m.storeOffer!.id,
          productId: m.storeOffer!.productId,
          basePlanId: m.storeOffer!.basePlanId,
          offerId: m.storeOffer!.offerId,
        ),
);

int? _ms(DateTime? date) => date?.toUtc().millisecondsSinceEpoch;

/// Encodes an entitlement.
EntitlementMessage encodeEntitlement(Entitlement e) => EntitlementMessage(
  state: e.state.name,
  productId: e.productId,
  renewsAtMs: _ms(e.renewsAt),
  expiresAtMs: _ms(e.expiresAt),
  gracePeriodEndsAtMs: _ms(e.gracePeriodEndsAt),
  source: e.source,
);

/// Decodes a person.
PersonSummary decodePerson(PersonMessage m) => PersonSummary(
  id: m.id,
  level: _byName(PersonLevel.values, m.level, PersonLevel.unknown),
  name: m.name,
);

/// Decodes a configuration problem.
ConfigurationProblem decodeProblem(ProblemMessage m) => ConfigurationProblem(
  kind: _byName(
    ConfigurationProblemKind.values,
    m.kind,
    ConfigurationProblemKind.unknown,
  ),
  message: m.message,
  disablesSdk: m.disablesSdk,
);

/// Decodes a state snapshot.
PingFrontState decodeState(StateMessage m) => PingFrontState(
  isConfigured: m.isConfigured,
  unreadCount: m.unreadCount,
  isChatVisible: m.isChatVisible,
  isTestDevice: m.isTestDevice,
  person: m.person == null ? null : decodePerson(m.person!),
  configurationProblem: m.configurationProblem == null
      ? null
      : decodeProblem(m.configurationProblem!),
);

/// Decodes a moment result.
MomentResult decodeMomentResult(MomentResultMessage m) => switch (m.kind) {
  'notListened' => const MomentNotListened(),
  'ignored' => const MomentIgnored(),
  'scheduled' => const MomentScheduled(),
  'delivered' => const MomentDelivered(),
  'heldOut' => const MomentHeldOut(),
  'openRequested' => MomentOpenRequested(presented: m.presented ?? false),
  'invalidName' => const MomentInvalidName(),
  'failed' => MomentFailed(
    PingFrontException(
      m.errorCode ?? 'unexpected',
      m.errorMessage ?? 'The moment could not be sent.',
    ),
  ),
  final other => MomentUnknown(other),
};

String? _string(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is String ? value : null;
}

int? _int(Map<String, Object?> data, String key) {
  final value = data[key];
  return value is int ? value : null;
}

bool _bool(Map<String, Object?> data, String key) => data[key] == true;

Map<String, Object?>? _map(Map<String, Object?> data, String key) {
  final value = data[key];
  if (value is! Map) return null;
  return {
    for (final entry in value.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

OfferRequest? _request(Map<String, Object?> data) {
  final r = _map(data, 'request');
  if (r == null) return null;
  final offerId = _string(r, 'offerId');
  final cardId = _string(r, 'cardId');
  final messageId = _string(r, 'messageId');
  if (offerId == null || cardId == null || messageId == null) return null;
  final store = _map(r, 'storeOffer');
  final storeKind = store == null ? null : _string(store, 'kind');
  final storeId = store == null ? null : _string(store, 'id');
  return OfferRequest(
    offerId: offerId,
    cardId: cardId,
    messageId: messageId,
    storeOffer: storeKind == null || storeId == null
        ? null
        : StoreOffer(
            kind: storeKind,
            id: storeId,
            productId: _string(store!, 'productId'),
            basePlanId: _string(store, 'basePlanId'),
            offerId: _string(store, 'offerId'),
          ),
  );
}

/// Decodes an event. Anything malformed or unknown becomes [PingFrontEvent.unknown].
PingFrontEvent decodeEvent(EventMessage m) {
  final data = {for (final entry in m.data.entries) entry.key: entry.value};
  final unknown = PingFrontEvent.unknown(m.type, data);
  switch (m.type) {
    case 'chatOpened':
      return const ChatOpened();
    case 'chatClosed':
      return const ChatClosed();
    case 'reportSent':
      return const ReportSent();
    case 'sessionRevoked':
      return const SessionRevoked();
    case 'unreadChanged':
      final count = _int(data, 'count');
      return count == null ? unknown : UnreadChanged(count);
    case 'messageReceived':
      final id = _string(data, 'id');
      final preview = _string(data, 'preview');
      if (id == null || preview == null) return unknown;
      return MessageReceived(
        ReceivedMessage(
          id: id,
          preview: preview,
          authorName: _string(data, 'authorName'),
          isPing: _bool(data, 'isPing'),
          isAi: _bool(data, 'isAi'),
        ),
      );
    case 'sessionStarted':
      final id = _string(data, 'personId');
      if (id == null) return unknown;
      return SessionStarted(
        PersonSummary(
          id: id,
          level: _byName(
            PersonLevel.values,
            _string(data, 'level'),
            PersonLevel.unknown,
          ),
          name: _string(data, 'name'),
        ),
      );
    case 'identityProblem':
      return IdentityProblemReported(_string(data, 'problem') ?? 'unknown');
    case 'offerRequested':
      final request = _request(data);
      return request == null ? unknown : OfferRequested(request);
    case 'offerCompleted':
      final request = _request(data);
      final outcome = _string(data, 'outcome');
      if (request == null || outcome == null) return unknown;
      return OfferCompleted(
        request,
        outcome,
        failure: _string(data, 'failure'),
      );
    case 'messageSent':
      final id = _string(data, 'id');
      if (id == null) return unknown;
      return MessageSent(
        SentMessage(
          id: id,
          textLength: _int(data, 'textLength') ?? 0,
          photoCount: _int(data, 'photoCount') ?? 0,
          repliesToPing: _bool(data, 'repliesToPing'),
        ),
      );
    case 'cardOpened':
      final kind = _string(data, 'kind');
      final cardId = _string(data, 'cardId');
      final messageId = _string(data, 'messageId');
      if (kind == null || cardId == null || messageId == null) return unknown;
      return CardOpened(
        OpenedCard(kind: CardKind(kind), cardId: cardId, messageId: messageId),
      );
    case 'lookChanged':
      final revision = _int(data, 'revision');
      if (revision == null) return unknown;
      return LookChanged(revision: revision, draft: _bool(data, 'draft'));
    case 'configurationProblem':
      final message = _string(data, 'message');
      if (message == null) return unknown;
      return ConfigurationProblemFound(
        ConfigurationProblem(
          kind: _byName(
            ConfigurationProblemKind.values,
            _string(data, 'kind'),
            ConfigurationProblemKind.unknown,
          ),
          message: message,
          disablesSdk: _bool(data, 'disablesSdk'),
        ),
      );
    default:
      return unknown;
  }
}
