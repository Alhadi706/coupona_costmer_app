import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'store_identity_theme.dart';

/// Dark-styled collapsible section card used to group identity form fields.
class IdentitySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  final bool initiallyExpanded;

  const IdentitySection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kIdentitySurfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kIdentityBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: kTeal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: kMint, size: 18),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kIdentityText,
            ),
          ),
          iconColor: kMint,
          collapsedIconColor: kIdentityMuted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: children,
        ),
      ),
    );
  }
}

/// Dark-themed text field matching the identity card style.
class IdentityTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final bool enabled;
  final TextInputType? keyboard;
  final IconData? icon;
  final Color? iconColor;
  final bool iconAtEnd;

  const IdentityTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.enabled = true,
    this.keyboard,
    this.icon,
    this.iconColor,
    this.iconAtEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconWidget = icon == null ? null : Icon(icon, size: 18, color: iconColor ?? kIdentityMuted);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kIdentityBorder),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: enabled,
        keyboardType: keyboard,
        style: const TextStyle(color: kIdentityText, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kIdentityMuted, fontSize: 12),
          floatingLabelStyle: const TextStyle(color: kMint),
          prefixIcon: iconAtEnd ? null : iconWidget,
          suffixIcon: iconAtEnd ? iconWidget : null,
          isDense: true,
          filled: true,
          fillColor: kIdentitySurface,
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kTeal),
          ),
        ),
      ),
    );
  }
}

/// Dark-styled open/closed status switch tile for the basics section.
class IdentityOpenStatusTile extends StatelessWidget {
  final bool isOpen;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const IdentityOpenStatusTile({
    super.key,
    required this.isOpen,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kIdentitySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kIdentityBorder),
      ),
      child: SwitchListTile(
        value: isOpen,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(
          isOpen ? 'store_open_status'.tr() : 'store_closed_status'.tr(),
          style: const TextStyle(color: kIdentityText, fontSize: 13),
        ),
        secondary: Icon(
          isOpen ? Icons.storefront : Icons.storefront_outlined,
          color: isOpen ? kMint : kIdentityMuted,
          size: 20,
        ),
        activeThumbColor: kMint,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// Save & preview action row for the identity card footer.
class IdentityActionsRow extends StatelessWidget {
  final bool saving;
  final bool enabled;
  final VoidCallback onSave;
  final VoidCallback onPreview;

  const IdentityActionsRow({
    super.key,
    required this.saving,
    required this.enabled,
    required this.onSave,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: enabled ? onSave : null,
            style: FilledButton.styleFrom(
              backgroundColor: kTeal,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined),
            label: Text('store_save_identity'.tr()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPreview,
            style: OutlinedButton.styleFrom(
              foregroundColor: kMint,
              side: const BorderSide(color: kTeal),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: Text('store_preview_button'.tr()),
          ),
        ),
      ],
    );
  }
}

/// 2-column compact grid of social media link fields with brand-colored icons.
class SocialLinksGrid extends StatelessWidget {
  final TextEditingController whatsapp;
  final TextEditingController instagram;
  final TextEditingController facebook;
  final TextEditingController tiktok;
  final bool enabled;

  const SocialLinksGrid({
    super.key,
    required this.whatsapp,
    required this.instagram,
    required this.facebook,
    required this.tiktok,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _field(whatsapp, 'store_whatsapp_label'.tr(), Icons.chat_outlined,
                  const Color(0xFF25D366), TextInputType.phone),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(instagram, 'store_social_instagram'.tr(),
                  Icons.camera_alt_outlined, const Color(0xFFE1306C)),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _field(facebook, 'store_social_facebook'.tr(), Icons.facebook_outlined,
                  const Color(0xFF1877F2)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(tiktok, 'store_social_tiktok'.tr(), Icons.music_note_outlined,
                  const Color(0xFF25F4EE)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color, [
    TextInputType? keyboard,
  ]) {
    return IdentityTextField(
      controller: controller,
      label: label,
      enabled: enabled,
      keyboard: keyboard,
      icon: icon,
      iconColor: color,
      iconAtEnd: true,
    );
  }
}
