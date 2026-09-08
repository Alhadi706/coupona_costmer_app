import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../login_screen.dart';

/// Routes the user back to the login screen after a marketplace session
/// expiry, clearing any stale credentials first. Use instead of surfacing
/// silent API failures when the session is gone.
Future<void> routeToLoginOnSessionExpired(BuildContext context) async {
  await AppSession.clear();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginPage()),
    (route) => false,
  );
}
