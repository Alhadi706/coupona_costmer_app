import 'package:flutter/material.dart';

/// Fallback shown by [ErrorWidget.builder] when a widget fails to build.
/// Intentionally free of inherited dependencies (no Theme, Directionality or
/// localization lookups) because it may be rendered outside any app scope.
class AppBuildErrorView extends StatelessWidget {
  const AppBuildErrorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: const Color(0xFFF8FAFC),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Color(0xFF0D9488), size: 40),
            SizedBox(height: 12),
            Text(
              'تعذر عرض هذا القسم مؤقتاً. يرجى تحديث الصفحة أو المحاولة لاحقاً.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
