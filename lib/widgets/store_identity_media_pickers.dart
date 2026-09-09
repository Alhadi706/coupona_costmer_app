import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

/// Tappable image box used for store logo / cover / gallery items.
/// Picks an image from the gallery, uploads it immediately and reports
/// the hosted URL via [onUploaded].
class StoreImagePickerBox extends StatefulWidget {
  final String imageUrl;
  final double width;
  final double height;
  final IconData icon;
  final String label;
  final bool enabled;
  final ValueChanged<String> onUploaded;

  const StoreImagePickerBox({
    super.key,
    required this.imageUrl,
    required this.icon,
    required this.label,
    required this.onUploaded,
    this.width = double.infinity,
    this.height = 110,
    this.enabled = true,
  });

  @override
  State<StoreImagePickerBox> createState() => _StoreImagePickerBoxState();
}

class _StoreImagePickerBoxState extends State<StoreImagePickerBox> {
  bool _uploading = false;

  Future<void> _pick() async {
    if (!widget.enabled || _uploading) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final url = await CompanyServerService.uploadImageBytes(
        await picked.readAsBytes(),
      );
      if (url != null && url.isNotEmpty) widget.onUploaded(url);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl.trim().isNotEmpty;
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kMerchantBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: _uploading
            ? const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: kTeal),
                ),
              )
            : hasImage
                ? Image.network(
                    widget.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
      ),
    );
  }

  Widget _placeholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(widget.icon, color: kTeal, size: 26),
        const SizedBox(height: 4),
        Text(
          widget.label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: kTealDark),
        ),
      ],
    );
  }
}

/// Horizontal gallery of store photos with add / remove support.
class StoreGalleryRow extends StatelessWidget {
  final List<String> urls;
  final bool enabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;
  final String addLabel;

  const StoreGalleryRow({
    super.key,
    required this.urls,
    required this.onAdd,
    required this.onRemove,
    required this.addLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          StoreImagePickerBox(
            imageUrl: '',
            width: 84,
            height: 92,
            icon: Icons.add_photo_alternate_outlined,
            label: addLabel,
            enabled: enabled,
            onUploaded: onAdd,
          ),
          const SizedBox(width: 8),
          ...urls.map(
            (url) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      url,
                      width: 84,
                      height: 92,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 84,
                        height: 92,
                        color: Colors.grey.shade100,
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (enabled)
                    Positioned(
                      top: 2,
                      left: 2,
                      child: InkWell(
                        onTap: () => onRemove(url),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
