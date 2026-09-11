import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/company_server_service.dart';
import 'coalitions/coalition_clearinghouse_screen.dart';

typedef PublicCoalitionRequestLoader = Future<Map<String, dynamic>?> Function(String applicantType);
typedef PublicCoalitionRequestAction = Future<Map<String, dynamic>> Function(String applicantType);
typedef PublicCoalitionCodeActivationAction = Future<Map<String, dynamic>> Function(String code);

/// Platform support WhatsApp number, provided at build time:
/// `--dart-define=KUPUNA_SUPPORT_WHATSAPP=2189XXXXXXXX`.
const String kPlatformSupportWhatsApp = String.fromEnvironment(
  'KUPUNA_SUPPORT_WHATSAPP',
  defaultValue: '',
);

class PublicCoalitionMembershipScreen extends StatefulWidget {
  final String applicantType;
  final PublicCoalitionRequestLoader? requestLoader;
  final PublicCoalitionRequestAction? requestAction;
  final PublicCoalitionCodeActivationAction? codeActivationAction;
  final String supportWhatsAppNumber;

  const PublicCoalitionMembershipScreen({
    super.key,
    required this.applicantType,
    this.requestLoader,
    this.requestAction,
    this.codeActivationAction,
    this.supportWhatsAppNumber = kPlatformSupportWhatsApp,
  });

  @override
  State<PublicCoalitionMembershipScreen> createState() => _PublicCoalitionMembershipScreenState();
}

class _PublicCoalitionMembershipScreenState extends State<PublicCoalitionMembershipScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _loading = true;
  bool _submitting = false;
  bool _activatingCode = false;
  String? _error;
  Map<String, dynamic>? _request;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PublicCoalitionMembershipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.applicantType != widget.applicantType) {
      _request = null;
      _load();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _tx(String key, String fallback) {
    final value = key.tr();
    return value == key ? fallback : value;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await (widget.requestLoader ??
          (type) => CompanyServerService.getPublicCoalitionMembershipRequest(applicantType: type))(widget.applicantType);
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final request = await (widget.requestAction ??
          (type) => CompanyServerService.requestPublicCoalitionMembership(applicantType: type))(widget.applicantType);
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _activateCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _activatingCode) return;
    setState(() => _activatingCode = true);
    try {
      final result = await (widget.codeActivationAction ??
          (value) => CompanyServerService.activateCoalitionCode(code: value))(code);
      if (!mounted) return;
      _codeController.clear();
      final credited = result['creditedPoints'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_tx(
            'public_coalition_code_activated',
            'تم تفعيل الرصيد بنجاح${credited != null ? ' (+$credited)' : ''}',
          )),
        ),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('public_coalition_code_activation_failed', 'تعذر تفعيل الكود. تأكد من الكود وحاول مجدداً.'))),
      );
    } finally {
      if (mounted) setState(() => _activatingCode = false);
    }
  }

  Future<void> _contactSupport() async {
    final rawNumber = widget.supportWhatsAppNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final message = _tx(
      'public_coalition_support_message',
      'مرحباً، أحتاج مساعدة بخصوص طلب تفعيل الائتلاف الذهبي.',
    );
    final uri = rawNumber.isEmpty
        ? Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/$rawNumber?text=${Uri.encodeComponent(message)}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_tx('public_coalition_support_open_failed', 'تعذر فتح قناة التواصل مع إدارة المنصة.'))),
      );
    }
  }

  String _statusLabel(String status) {
    return switch (status) {
      'pending_admin_review' => _tx('public_coalition_status_pending', 'طلبك قيد المراجعة'),
      'approved_pending_payment' => _tx('public_coalition_status_pending', 'طلبك قيد المراجعة'),
      'active' => _tx('public_coalition_status_active', 'Active'),
      'rejected' => _tx('public_coalition_status_rejected', 'Rejected'),
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_tx('public_coalition_membership_title', 'Public coalition membership'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.public, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      _tx('public_coalition_membership_description',
                          'قدّم طلب الانضمام إلى شبكة كوبونا العامة. يتم التفعيل بعد مراجعة إدارة المنصة وتعبئة رصيدك عبر كود تفعيل.'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (widget.applicantType == 'merchant' &&
                _request?['status'] != 'active') ...[
              _buildActivationCodeCard(),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_off_outlined),
                  title: Text(_tx('public_coalition_load_failed', 'Unable to load your application.')),
                  trailing: IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
                ),
              )
            else
              _buildRequestState(),
          ],
        ),
      ),
    );
  }

  Widget _buildActivationCodeCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _tx('public_coalition_activation_code_title', 'تفعيل الرصيد الذهبي'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _tx('public_coalition_activation_code_hint',
                  'إذا استلمت كود تفعيل من إدارة المنصة، أدخله هنا لتعبئة رصيدك الذهبي فوراً.'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('public-coalition-activation-code-input'),
              controller: _codeController,
              textDirection: ui.TextDirection.ltr,
              decoration: InputDecoration(
                labelText: _tx('public_coalition_activation_code_label', 'أدخل كود تفعيل الرصيد'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('public-coalition-activate-code'),
              onPressed: _activatingCode ? null : _activateCode,
              icon: const Icon(Icons.bolt_outlined),
              label: Text(_activatingCode
                  ? _tx('public_coalition_activating_code', 'جارٍ التفعيل...')
                  : _tx('public_coalition_activate_code', 'تفعيل الرصيد')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingGuidance() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _tx('public_coalition_pending_guidance',
                        'سيقوم مسؤول المنصة بمراجعة طلبك وإرسال تفاصيل التفعيل وتعبئة رصيدك.'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('public-coalition-contact-support'),
          onPressed: _contactSupport,
          icon: const Icon(Icons.chat_outlined, color: Colors.green),
          label: Text(_tx('public_coalition_contact_support', 'التواصل مع إدارة المنصة')),
        ),
      ],
    );
  }

  Widget _buildRequestState() {
    final request = _request;
    if (request == null || request['status'] == 'rejected' || request['status'] == 'cancelled') {
      final rejectionReason = request?['rejectionReason']?.toString() ?? '';
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rejectionReason.isNotEmpty) ...[
                Text(_statusLabel('rejected'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(rejectionReason),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                key: const Key('public-coalition-submit-request'),
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send_outlined),
                label: Text(_submitting
                    ? _tx('public_coalition_submitting', 'Submitting...')
                    : _tx('public_coalition_submit', 'تقديم طلب تفعيل الائتلاف الذهبي')),
              ),
            ],
          ),
        ),
      );
    }

    final status = request['status']?.toString() ?? '';
    final adminMessage = request['adminMessage']?.toString() ?? '';
    final awaitingReview = status == 'pending_admin_review' || status == 'approved_pending_payment';
    final isActive = status == 'active';
    return Card(
      key: Key('public-coalition-status-$status'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isActive)
              Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tx(
                        'public_coalition_active_message',
                        'عضويتك في الائتلاف العام نشطة وجاهزة للاستخدام',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              )
            else
              Text(
                _statusLabel(status),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            if (!isActive && adminMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_tx('public_coalition_admin_message', 'Private message from administration')),
              const SizedBox(height: 4),
              SelectableText(adminMessage),
            ],
            if (awaitingReview) _buildPendingGuidance(),
            if (isActive) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const Key('public-coalition-open-clearinghouse'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CoalitionClearinghouseScreen(),
                  ),
                ),
                icon: const Icon(Icons.account_balance_outlined),
                label: Text(
                  _tx(
                    'public_coalition_open_clearinghouse',
                    'الانتقال لغرفة المقاصة والائتلافات',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}