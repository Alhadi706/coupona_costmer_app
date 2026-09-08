import 'package:easy_localization/easy_localization.dart';

/// Maps raw API/transport failures to friendly localized messages.
String marketplaceErrorMessage(Object error, {required String fallbackKey}) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('unauthorized') ||
      raw.contains('(401)') ||
      raw.contains('(403)') ||
      raw.contains('forbidden')) {
    return 'marketplace_session_expired'.tr();
  }
  return fallbackKey.tr();
}
