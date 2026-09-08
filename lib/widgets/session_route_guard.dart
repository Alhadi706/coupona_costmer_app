import 'package:flutter/material.dart';

import '../services/app_session.dart';

/// Blocks deep-linked role routes (e.g. `#/merchant/analytics`) when the stored
/// session is missing or belongs to another role, instead of letting the target
/// screen build against a null token and crash into a blank screen.
class SessionRouteGuard extends StatefulWidget {
  final List<String> allowedRoles;
  final WidgetBuilder builder;
  final WidgetBuilder fallbackBuilder;

  const SessionRouteGuard({
    super.key,
    required this.allowedRoles,
    required this.builder,
    required this.fallbackBuilder,
  });

  @override
  State<SessionRouteGuard> createState() => _SessionRouteGuardState();
}

class _SessionRouteGuardState extends State<SessionRouteGuard> {
  late final Future<bool> _allowed = _resolveAccess();

  Future<bool> _resolveAccess() async {
    try {
      final token = await AppSession.token().timeout(const Duration(seconds: 3));
      if (token == null || token.trim().isEmpty) return false;
      if (widget.allowedRoles.isEmpty) return true;
      final role = await AppSession.role().timeout(const Duration(seconds: 3));
      return widget.allowedRoles.contains(role);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _allowed,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data != true) {
          return widget.fallbackBuilder(context);
        }
        return widget.builder(context);
      },
    );
  }
}
