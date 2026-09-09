import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../screens/map_picker_screen.dart';
import '../screens/store_details_screen.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'store_identity_hero_header.dart';
import 'store_identity_media_pickers.dart';
import 'store_identity_sections.dart';
import 'store_identity_theme.dart';

/// Customer-facing digital identity hub of the store tab: hero cover & logo
/// header with live status badge, gallery, grouped collapsible sections for
/// basic info / contact channels / location, and a live preview action.
class StoreDigitalIdentityCard extends StatefulWidget {
  final Map<String, dynamic> merchantProfile;
  final bool readOnly;
  final Future<void> Function() onSaved;

  const StoreDigitalIdentityCard({
    super.key,
    required this.merchantProfile,
    required this.onSaved,
    this.readOnly = false,
  });

  @override
  State<StoreDigitalIdentityCard> createState() => _StoreDigitalIdentityCardState();
}

class _StoreDigitalIdentityCardState extends State<StoreDigitalIdentityCard> {
  late final TextEditingController _description;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _tiktok;
  late final TextEditingController _workingHours;
  late final TextEditingController _address;
  late String _logoUrl;
  late String _coverUrl;
  late List<String> _gallery;
  double? _lat;
  double? _lng;
  late bool _isOpen;
  bool _saving = false;

  String _s(String key) => (widget.merchantProfile[key] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _description = TextEditingController(text: _s('description'));
    _phone = TextEditingController(text: _s('phone'));
    _whatsapp = TextEditingController(text: _s('whatsapp'));
    _instagram = TextEditingController(text: _s('instagramUrl'));
    _facebook = TextEditingController(text: _s('facebookUrl'));
    _tiktok = TextEditingController(text: _s('tiktokUrl'));
    _workingHours = TextEditingController(text: _s('workingHours'));
    _address = TextEditingController(text: _s('locationAddress'));
    _logoUrl = _s('logoUrl');
    _coverUrl = _s('coverUrl');
    final gallery = widget.merchantProfile['galleryUrls'];
    _gallery = gallery is List
        ? gallery.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final lat = widget.merchantProfile['locationLat'];
    final lng = widget.merchantProfile['locationLng'];
    _lat = lat == null ? null : double.tryParse(lat.toString());
    _lng = lng == null ? null : double.tryParse(lng.toString());
    _isOpen = widget.merchantProfile['isOpen'] != false;
  }

  @override
  void dispose() {
    _description.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _tiktok.dispose();
    _workingHours.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLocation: (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null,
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _lat = picked.latitude;
      _lng = picked.longitude;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await CompanyServerService.updateMerchantProfile(
        description: _description.text.trim(),
        phone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim(),
        instagramUrl: _instagram.text.trim(),
        facebookUrl: _facebook.text.trim(),
        tiktokUrl: _tiktok.text.trim(),
        workingHours: _workingHours.text.trim(),
        locationAddress: _address.text.trim(),
        locationLat: _lat,
        locationLng: _lng,
        logoUrl: _logoUrl,
        coverUrl: _coverUrl,
        galleryUrls: _gallery,
        isOpen: _isOpen,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('store_identity_saved'.tr()), backgroundColor: kTeal),
      );
      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${'store_identity_save_failed'.tr()}: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _preview() {
    final merchantId = _s('id');
    if (merchantId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreDetailsScreen(store: <String, dynamic>{
          'merchantId': merchantId,
          'name': _s('businessName'),
          'logoUrl': _logoUrl,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = !widget.readOnly && !_saving;
    return Container(
      decoration: BoxDecoration(
        color: kIdentitySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kIdentityBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StoreIdentityHeroHeader(
            coverUrl: _coverUrl,
            logoUrl: _logoUrl,
            isOpen: _isOpen,
            enabled: editable,
            onCoverUploaded: (url) => setState(() => _coverUrl = url),
            onLogoUploaded: (url) => setState(() => _logoUrl = url),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'store_gallery_label'.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: kIdentityText,
                  ),
                ),
                const SizedBox(height: 8),
                StoreGalleryRow(
                  urls: _gallery,
                  enabled: editable,
                  addLabel: 'store_add_photo'.tr(),
                  onAdd: (url) => setState(() {
                    if (!_gallery.contains(url)) _gallery.add(url);
                  }),
                  onRemove: (url) => setState(() => _gallery.remove(url)),
                ),
                const SizedBox(height: 14),
                IdentitySection(
                  icon: Icons.edit_note_outlined,
                  title: 'identity_section_basics'.tr(),
                  initiallyExpanded: true,
                  children: [
                    IdentityTextField(
                      controller: _description,
                      label: 'store_description_label'.tr(),
                      maxLines: 3,
                      enabled: editable,
                    ),
                    IdentityTextField(
                      controller: _workingHours,
                      label: 'merchant_working_hours'.tr(),
                      enabled: editable,
                      icon: Icons.schedule_outlined,
                    ),
                    IdentityOpenStatusTile(
                      isOpen: _isOpen,
                      enabled: editable,
                      onChanged: (v) => setState(() => _isOpen = v),
                    ),
                  ],
                ),
                IdentitySection(
                  icon: Icons.call_outlined,
                  title: 'identity_section_contact'.tr(),
                  children: [
                    IdentityTextField(
                      controller: _phone,
                      label: 'merchant_phone'.tr(),
                      keyboard: TextInputType.phone,
                      enabled: editable,
                      icon: Icons.phone_outlined,
                    ),
                    SocialLinksGrid(
                      whatsapp: _whatsapp,
                      instagram: _instagram,
                      facebook: _facebook,
                      tiktok: _tiktok,
                      enabled: editable,
                    ),
                  ],
                ),
                IdentitySection(
                  icon: Icons.place_outlined,
                  title: 'identity_section_location'.tr(),
                  children: [
                    IdentityTextField(
                      controller: _address,
                      label: 'store_location_label'.tr(),
                      enabled: editable,
                      icon: Icons.location_on_outlined,
                    ),
                    if (editable)
                      OutlinedButton.icon(
                        onPressed: _pickLocation,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kMint,
                          side: const BorderSide(color: kTeal),
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: Text('store_pick_location'.tr()),
                      ),
                    if (_lat != null && _lng != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, size: 13, color: kMint),
                            const SizedBox(width: 5),
                            Text(
                              '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 12, color: kMint),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                IdentityActionsRow(
                  saving: _saving,
                  enabled: editable,
                  onSave: _save,
                  onPreview: _preview,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
