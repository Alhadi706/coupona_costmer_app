import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'store_identity_theme.dart';

/// Modern hero header for the store digital identity card: full-width cover
/// banner with a gradient overlay, a circular store logo avatar overlapping
/// the banner corner, quick camera overlays and a live open/closed badge.
class StoreIdentityHeroHeader extends StatefulWidget {
  final String coverUrl;
  final String logoUrl;
  final bool isOpen;
  final bool enabled;
  final ValueChanged<String> onCoverUploaded;
  final ValueChanged<String> onLogoUploaded;

  const StoreIdentityHeroHeader({
    super.key,
    required this.coverUrl,
    required this.logoUrl,
    required this.isOpen,
    required this.onCoverUploaded,
    required this.onLogoUploaded,
    this.enabled = true,
  });

  @override
  State<StoreIdentityHeroHeader> createState() => _StoreIdentityHeroHeaderState();
}

class _StoreIdentityHeroHeaderState extends State<StoreIdentityHeroHeader> {
  bool _uploadingCover = false;
  bool _uploadingLogo = false;

  Future<void> _pick({required bool isCover}) async {
    if (!widget.enabled || (isCover ? _uploadingCover : _uploadingLogo)) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => isCover ? _uploadingCover = true : _uploadingLogo = true);
    try {
      final url = await CompanyServerService.uploadImageBytes(await picked.readAsBytes());
      if (url != null && url.isNotEmpty) {
        isCover ? widget.onCoverUploaded(url) : widget.onLogoUploaded(url);
      }
    } finally {
      if (mounted) setState(() => isCover ? _uploadingCover = false : _uploadingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 174,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildCover(),
          Positioned(top: 10, right: 10, child: _StatusBadge(isOpen: widget.isOpen)),
          Positioned(bottom: 0, right: 16, child: _buildLogo()),
        ],
      ),
    );
  }

  Widget _buildCover() {
    final hasCover = widget.coverUrl.trim().isNotEmpty;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onTap: () => _pick(isCover: true),
        child: Container(
          height: 128,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [kTeal, kIndigo],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                Image.network(
                  widget.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black45],
                  ),
                ),
              ),
              if (!hasCover)
                const Center(child: Icon(Icons.panorama_outlined, color: Colors.white54, size: 34)),
              if (_uploadingCover)
                const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
              Positioned(
                left: 12,
                bottom: 10,
                right: 104,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'store_identity_title'.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                      Text(
                        'store_identity_subtitle'.tr(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.5,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.enabled && !_uploadingCover)
                Positioned(top: 10, left: 10, child: _CameraChip(label: 'store_cover_label'.tr())),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    final hasLogo = widget.logoUrl.trim().isNotEmpty;
    return GestureDetector(
      onTap: () => _pick(isCover: false),
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: kIdentitySurfaceAlt,
          border: Border.all(color: kIdentitySurface, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasLogo)
              Image.network(
                widget.logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.storefront_outlined, color: kMint, size: 30),
              )
            else
              const Icon(Icons.storefront_outlined, color: kMint, size: 30),
            if (_uploadingLogo)
              const ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  ),
                ),
              ),
            if (widget.enabled && !_uploadingLogo)
              const Align(
                alignment: Alignment.bottomCenter,
                child: ColoredBox(
                  color: Colors.black45,
                  child: SizedBox(
                    width: double.infinity,
                    child: Icon(Icons.photo_camera_outlined, size: 14, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraChip extends StatelessWidget {
  final String label;

  const _CameraChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_camera_outlined, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? const Color(0xFF22C55E) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            (isOpen ? 'store_open_badge' : 'store_closed_badge').tr(),
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
