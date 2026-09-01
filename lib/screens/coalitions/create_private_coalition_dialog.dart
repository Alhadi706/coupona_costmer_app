import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../services/company_server_service.dart';
import '../../theme/design_tokens.dart';

class CreatePrivateCoalitionDialog extends StatefulWidget {
  const CreatePrivateCoalitionDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const CreatePrivateCoalitionDialog(),
    );
  }

  @override
  State<CreatePrivateCoalitionDialog> createState() => _CreatePrivateCoalitionDialogState();
}

class _CreatePrivateCoalitionDialogState extends State<CreatePrivateCoalitionDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _merchantIdsController = TextEditingController();
  final TextEditingController _rulesController = TextEditingController();
  bool _submitting = false;
  bool _loadingSuggestions = false;
  String _activityFilter = 'same';
  String? _suggestionsError;
  List<Map<String, dynamic>> _suggestedMerchants = const <Map<String, dynamic>>[];
  final Set<String> _selectedSuggestedMerchantIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _merchantIdsController.dispose();
    _rulesController.dispose();
    super.dispose();
  }

  String _normalizeInvitee(String raw) => raw.trim().replaceAll(RegExp(r'[^0-9a-zA-Z_-]'), '');

  Future<void> _loadSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestionsError = null;
    });

    try {
      final data = await CompanyServerService.getMerchantCoalitionSuggestions(
        activityFilter: _activityFilter,
        radiusKm: 50,
        limit: 24,
      );
      if (!mounted) return;
      final suggestions = List<Map<String, dynamic>>.from(data['suggestions'] ?? const <dynamic>[]);
      setState(() {
        _suggestedMerchants = suggestions;
        _selectedSuggestedMerchantIds.removeWhere(
          (id) => !_suggestedMerchants.any((entry) => (entry['id'] ?? '').toString() == id),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _suggestionsError = error.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _submit() async {
    final coalitionName = _nameController.text.trim();
    final invitees = _merchantIdsController.text
        .split(RegExp(r'[\n,;]'))
        .map(_normalizeInvitee)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final selectedInvitees = <String>{
      ..._selectedSuggestedMerchantIds,
      ...invitees,
    }.toList(growable: false);

    if (coalitionName.isEmpty) {
      _showMessage('coalition_create_name_required'.tr());
      return;
    }
    if (selectedInvitees.length < 2 || selectedInvitees.length > 5) {
      _showMessage('coalition_create_invitees_range'.tr());
      return;
    }

    setState(() => _submitting = true);
    try {
      final created = await CompanyServerService.createMerchantCoalition(
        name: coalitionName,
        type: 'private',
        category: 'Private',
        region: 'Custom',
        monthlyPointsCap: 500,
      );
      final coalitionId = (created['coalition_id'] ?? created['id'] ?? '').toString();
      if (coalitionId.isEmpty) {
        throw StateError('coalition_create_missing_id'.tr());
      }

      for (final invitee in selectedInvitees) {
        await CompanyServerService.inviteMerchantToCoalition(coalitionId, invitee);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('coalition_create_success'.tr())),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('coalition_create_private'.tr()),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'coalition_create_name_label'.tr()),
              ),
              const SizedBox(height: 12),
              _buildSuggestionsSection(),
              const SizedBox(height: 12),
              TextField(
                controller: _merchantIdsController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'coalition_create_invitees_label'.tr(),
                  hintText: 'coalition_create_invitees_hint'.tr(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rulesController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'coalition_create_rules_label'.tr(),
                  hintText: 'coalition_create_rules_hint'.tr(),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kIndigo.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'coalition_create_help'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text('coalition_cancel'.tr()),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send_outlined),
          label: Text(_submitting ? 'coalition_sending'.tr() : 'coalition_create_and_invite'.tr()),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'coalition_create_suggestions_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: _loadingSuggestions ? null : _loadSuggestions,
              icon: const Icon(Icons.refresh),
              tooltip: 'clearinghouse_refresh'.tr(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterChip('same', 'coalition_filter_same_activity'.tr()),
            _buildFilterChip('different', 'coalition_filter_different_activity'.tr()),
            _buildFilterChip('all', 'coalition_filter_all'.tr()),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingSuggestions) const LinearProgressIndicator(),
        if (_suggestionsError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'coalition_suggestions_load_failed'.tr(),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
        if (!_loadingSuggestions && _suggestedMerchants.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'coalition_suggestions_empty'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        if (_suggestedMerchants.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestedMerchants.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final merchant = _suggestedMerchants[index];
                final merchantId = (merchant['id'] ?? '').toString();
                final name = (merchant['business_name'] ?? 'coalition_unknown'.tr()).toString();
                final distanceRaw = merchant['distance_km'];
                final distance = distanceRaw == null
                    ? 'coalition_distance_unknown'.tr()
                    : '${(double.tryParse(distanceRaw.toString()) ?? 0).toStringAsFixed(1)} ${'coalition_distance_km'.tr()}';
                final activity = (merchant['activity_category'] ?? '').toString();
                final activityLabel = activity.isEmpty
                    ? 'coalition_activity_unknown'.tr()
                    : activity;
                final sameActivity = merchant['same_activity'] == true;

                return CheckboxListTile(
                  value: _selectedSuggestedMerchantIds.contains(merchantId),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        _selectedSuggestedMerchantIds.add(merchantId);
                      } else {
                        _selectedSuggestedMerchantIds.remove(merchantId);
                      }
                    });
                  },
                  title: Text(name),
                  subtitle: Text(
                    'coalition_suggestion_item_meta'.tr(namedArgs: {
                      'distance': distance,
                      'activity': activityLabel,
                      'match': sameActivity
                          ? 'coalition_filter_same_activity'.tr()
                          : 'coalition_filter_different_activity'.tr(),
                    }),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return ChoiceChip(
      selected: _activityFilter == value,
      label: Text(label),
      onSelected: (selected) {
        if (!selected || _activityFilter == value) return;
        setState(() => _activityFilter = value);
        _loadSuggestions();
      },
    );
  }
}
