import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';

class FoundationVerificationReport {
  FoundationVerificationReport({
    required this.serverOnlyMode,
    required this.localizationAssetsReady,
    required this.preferencesReady,
  });

  final bool serverOnlyMode;
  final bool localizationAssetsReady;
  final bool preferencesReady;

  bool get isStable =>
      serverOnlyMode && localizationAssetsReady && preferencesReady;

  String asLogString() {
    return 'stable=$isStable '
        'serverOnlyMode=$serverOnlyMode '
        'localizationAssetsReady=$localizationAssetsReady '
        'preferencesReady=$preferencesReady';
  }
}

class FoundationVerifier {
  Future<FoundationVerificationReport> verify() async {
    const bool serverOnlyMode = true;
    final bool localizationAssetsReady = await _canLoadLocalizationAsset();
    final bool preferencesReady = await _canReadPreferences();

    AppLogger.info('Server-only mode enabled.');
    if (!localizationAssetsReady) {
      AppLogger.warning('Localization asset not readable: assets/lang/ar.json');
    }
    if (!preferencesReady) {
      AppLogger.warning('SharedPreferences is not readable.');
    }

    return FoundationVerificationReport(
      serverOnlyMode: serverOnlyMode,
      localizationAssetsReady: localizationAssetsReady,
      preferencesReady: preferencesReady,
    );
  }

  Future<bool> _canLoadLocalizationAsset() async {
    try {
      final String data = await rootBundle.loadString('assets/lang/ar.json');
      return data.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _canReadPreferences() async {
    try {
      await SharedPreferences.getInstance();
      return true;
    } catch (_) {
      return false;
    }
  }
}
