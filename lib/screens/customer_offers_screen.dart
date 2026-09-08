import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import 'customer_offers_screen_create_sheet.dart';
import 'customer_offers_screen_widgets.dart';

class CustomerOffersScreen extends StatefulWidget {
  const CustomerOffersScreen({super.key});

  @override
  State<CustomerOffersScreen> createState() => _CustomerOffersScreenState();
}

class _CustomerOffersScreenState extends State<CustomerOffersScreen> {
  late Future<List<Map<String, dynamic>>> _offersFuture;
  bool _showMyOffers = false;

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    _offersFuture = CompanyServerService.getCustomerCommunityOffers(
      myOnly: _showMyOffers,
    );
  }

  Future<void> _refreshOffers() async {
    setState(_loadOffers);
    await _offersFuture;
  }

  Future<void> _showCreateOfferSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateCustomerOfferSheet(),
    );
    if (created == true && mounted) {
      await _refreshOffers();
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> offer, String status) async {
    final offerId = (offer['id'] ?? '').toString();
    if (offerId.isEmpty) return;
    try {
      await CompanyServerService.updateCommunityOfferStatus(
        offerId: offerId,
        status: status,
      );
      if (!mounted) return;
      await _refreshOffers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحديث حالة العرض: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عروض الزبائن'),
        backgroundColor: kTealDark,
        foregroundColor: kWhite,
        actions: [
          IconButton(
            onPressed: _refreshOffers,
            icon: const Icon(Icons.refresh),
            tooltip: 'refresh'.tr(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOfferSheet,
        backgroundColor: kTeal,
        foregroundColor: kWhite,
        icon: const Icon(Icons.add),
        label: Text('add_offer'.tr()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text('all_offers'.tr())),
                ButtonSegment(value: true, label: Text('my_requests'.tr())),
              ],
              selected: {_showMyOffers},
              onSelectionChanged: (selection) {
                setState(() {
                  _showMyOffers = selection.first;
                  _loadOffers();
                });
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _offersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: FilledButton.icon(
                      onPressed: _refreshOffers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('تعذر تحميل العروض، أعد المحاولة'),
                    ),
                  );
                }
                final offers = snapshot.data ?? const <Map<String, dynamic>>[];
                if (offers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _showMyOffers
                            ? 'لم تضف أي عروض أو طلبات بعد.'
                            : 'لا توجد عروض زبائن متاحة حالياً.',
                        textAlign: TextAlign.center,
                        style: kBodyTextStyle(size: 15, color: kInk.withValues(alpha: 0.7)),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refreshOffers,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: offers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => CustomerOfferCard(
                      offer: offers[index],
                      onStatusChanged: _updateStatus,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
