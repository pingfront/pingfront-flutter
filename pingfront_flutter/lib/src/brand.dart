import 'chat_view.dart' show PingFrontChatView;

/// The product name and every identifier derived from it, in one place.
///
/// The native sides keep their own copy in one file each (`ios/.../Names.swift`,
/// `android/.../Names.kt`). A rename changes these three files, the package name in
/// `pubspec.yaml` and `pigeons/messages.dart` (then `tool/pigeon.sh`), and the docs.
abstract final class Brand {
  /// The product name, as written in copy (sentence case, lowercase).
  static const String productName = 'pingfront';

  /// The prefix of the one-line self-check result, the same on every platform.
  static const String selfCheckPrefix = 'PingFront self-check:';

  /// The docs site, for links in error messages.
  static const String docsUrl = 'https://pingfront.sh/docs';

  /// The production API.
  static const String productionApi = 'https://api.pingfront.sh/v1';

  /// The key in a push payload that marks it as ours (APNs: an object; FCM: the `pf_` prefix).
  static const String pushKey = 'pingfront';

  /// The prefix of every FCM data key the server sends.
  static const String fcmKeyPrefix = 'pf_';

  /// The platform view type of the embedded chat ([PingFrontChatView]).
  static const String chatViewType = 'dev.pingfront/chat_view';
}
