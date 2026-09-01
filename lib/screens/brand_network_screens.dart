import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';

class BrandCoalitionsScreen extends StatefulWidget {
  const BrandCoalitionsScreen({super.key});

  @override
  State<BrandCoalitionsScreen> createState() => _BrandCoalitionsScreenState();
}

class _BrandCoalitionsScreenState extends State<BrandCoalitionsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _coalitions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await CompanyServerService.getBrandCoalitions();
      if (!mounted) return;
      setState(() => _coalitions = List<Map<String, dynamic>>.from(result['coalitions'] ?? const []));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(String coalitionId) async {
    try {
      await CompanyServerService.joinBrandCoalition(coalitionId);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('coalition_join_request_confirmed'.tr())),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('brand_network_coalitions'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('coalition_public_join_description'.tr()),
                      const SizedBox(height: 12),
                      if (_coalitions.isEmpty)
                        Text('coalition_discover_empty'.tr())
                      else
                        ..._coalitions.map((coalition) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.public),
                                title: Text((coalition['name'] ?? 'coalition_unknown'.tr()).toString()),
                                subtitle: Text('coalition_discover_summary'.tr(namedArgs: {
                                  'type': (coalition['type'] ?? 'general').toString(),
                                  'members': (coalition['member_count'] ?? 0).toString(),
                                  'region': (coalition['region'] ?? 'coalition_region_global'.tr()).toString(),
                                })),
                                trailing: FilledButton(
                                  onPressed: coalition['is_member'] == true
                                      ? null
                                      : () => _join((coalition['id'] ?? '').toString()),
                                  child: Text(coalition['is_member'] == true
                                      ? 'coalition_joined'.tr()
                                      : 'coalition_join_request'.tr()),
                                ),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}

class BrandCoalitionClearinghouseScreen extends StatefulWidget {
  const BrandCoalitionClearinghouseScreen({super.key});

  @override
  State<BrandCoalitionClearinghouseScreen> createState() => _BrandCoalitionClearinghouseScreenState();
}

class _BrandCoalitionClearinghouseScreenState extends State<BrandCoalitionClearinghouseScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _statements = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await CompanyServerService.getBrandCoalitionClearinghouse();
      if (mounted) setState(() => _statements = result['statements'] ?? []);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('brand_network_clearinghouse'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('brand_network_clearinghouse_hint'.tr()),
                      const SizedBox(height: 16),
                      if (_statements.isEmpty)
                        Text('clearinghouse_no_ledger'.tr())
                      else
                        ..._statements.map((statement) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.account_balance_outlined),
                                title: Text((statement['coalition_name'] ?? 'coalition_label'.tr()).toString()),
                                subtitle: Text((statement['statement_type'] ?? '').toString()),
                                trailing: Text((statement['total_points'] ?? 0).toString()),
                              ),
                            )),
                    ],
                  ),
                ),
    );
  }
}
