import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:pingfront_flutter/pingfront_flutter.dart';
import 'package:pingfront_flutter/src/messages.g.dart';

/// The pingfront API's shared conformance fixtures (`flutter test` runs in the package folder).
const fixturesPath = 'test/fixtures';

class MockHostApi extends Mock implements PingFrontHostApi {}

/// The platform seam with a mocked host API and controllable native streams.
class FakePlatform implements PingFrontPlatform {
  FakePlatform(this.host);

  @override
  final PingFrontHostApi host;

  // Closed in close().
  // ignore: close_sinks
  final events$ = StreamController<EventMessage>.broadcast();
  // ignore: close_sinks
  final unread$ = StreamController<int>.broadcast();
  // ignore: close_sinks
  final teamActions$ = StreamController<TeamActionMessage>.broadcast();
  // ignore: close_sinks
  final conversation$ = StreamController<ConversationMessage>.broadcast();
  // ignore: close_sinks
  final looks$ = StreamController<LookMessage>.broadcast();
  PingFrontFlutterApi? flutterApi;

  @override
  Stream<EventMessage> events() => events$.stream;

  @override
  Stream<int> unreadCounts() => unread$.stream;

  @override
  Stream<TeamActionMessage> teamActions() => teamActions$.stream;

  @override
  Stream<ConversationMessage> conversationStates() => conversation$.stream;

  @override
  Stream<LookMessage> looks() => looks$.stream;

  @override
  void setUpFlutterApi(PingFrontFlutterApi? api) => flutterApi = api;

  Future<void> close() async {
    await events$.close();
    await unread$.close();
    await teamActions$.close();
    await conversation$.close();
    await looks$.close();
  }
}

/// Fallback values for mocktail's `any()`.
void registerFallbacks() {
  registerFallbackValue(
    ConfigureRequest(
      appKey: '',
      appearance: AppearanceMessage(),
      modules: [],
      logLevel: 'info',
      presentsChatForMoments: true,
      handlesOffers: false,
      closesChatForOffers: true,
      handlesLinks: false,
      wrapperVersion: '0.0.0',
      forwardsLogs: false,
    ),
  );
  registerFallbackValue(EntitlementMessage(state: 'none'));
  registerFallbackValue(TopicMessage(id: '', symbol: 'other'));
  registerFallbackValue(<OfferSlotMessage>[]);
  registerFallbackValue(<String, Object?>{});
}
