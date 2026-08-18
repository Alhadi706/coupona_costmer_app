import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

enum StatusPillKind {
  pending,
  approvedTeal,
  approvedMint,
  rejected,
}

class KupunaStatusPill extends StatelessWidget {
  final StatusPillKind kind;
  final String? labelOverride;

  const KupunaStatusPill({
    super.key,
    required this.kind,
    this.labelOverride,
  });

  @override
  Widget build(BuildContext context) {
    final _StatusStyle style = _statusStyleFor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: kStatusPillHorizontalPadding,
        vertical: kStatusPillVerticalPadding,
      ),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Text(
        labelOverride ?? style.label,
        style: kBodyTextStyle(
          size: kStatusPillFontSize,
          weight: FontWeight.w600,
          color: style.foreground,
        ),
      ),
    );
  }

  _StatusStyle _statusStyleFor(StatusPillKind value) {
    switch (value) {
      case StatusPillKind.pending:
        return const _StatusStyle('معلّقة', kGold, kInk);
      case StatusPillKind.approvedTeal:
        return const _StatusStyle('مقبولة', kTeal, kWhite);
      case StatusPillKind.approvedMint:
        return const _StatusStyle('نشط', kMint, kInk);
      case StatusPillKind.rejected:
        return _StatusStyle('مرفوضة', kInk.withValues(alpha: 0.15), kInk);
    }
  }
}

class _StatusStyle {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusStyle(this.label, this.background, this.foreground);
}
