import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/company_server_service.dart';
import '../../theme/design_tokens.dart';
import 'community_marketplace_errors.dart';
import 'community_marketplace_toolbar.dart';
import 'create_offer_dialog.dart';
import 'customer_offer_card.dart';

/// P2P customer marketplace ("سوق الزبائن والعروض") shown as a tab of the
/// Communities & Marketplace hub.
class CommunityMarketplaceTab extends StatefulWidget {
  const CommunityMarketplaceTab({super.key});

  @override
  State<CommunityMarketplaceTab> createState() => _CommunityMarketplaceTabState();
}

class _CommunityMarketplaceTabState extends State<CommunityMarketplaceTab> {
  late Future<List<Map<String, dynamic>>> _offersFuture;
  bool _showMyOffers = false;
  String _category = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  void _loadOffers() {
    _offersFuture = _fetchOffers();
  }

  Future<List<Map<String, dynamic>>> _fetchOffers() async {
    final token = await AppSession.token();
    if (token == null || token.isEmpty) {
      throw StateError('unauthorized');
    }
    return CompanyServerService.getCustomerCommunityOffers(
      myOnly: _showMyOffers,
      category: _category == 'ALL' ? null : _category,
    );
  }

  Future<void> _refreshOffers() async {
    setState(_loadOffers);
    await _offersFuture.catchError((_) => <Map<String, dynamic>>[]);
  }

  void _applyFilters({bool? myOffers, String? category}) {
    setState(() {
      if (myOffers != null) _showMyOffers = myOffers;
      if (category != null) _category = category;
      _loadOffers();
    });
  }

  Future<void> _openCreateOffer() async {
    final created = await CreateOfferDialog.show(context);
    if (created && mounted) {
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
        SnackBar(
          content: Text(
            marketplaceErrorMessage(error, fallbackKey: 'marketplace_status_update_failed'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CommunityMarketplaceToolbar(
          showMyOffers: _showMyOffers,
          category: _category,
          onScopeChanged: (value) => _applyFilters(myOffers: value),
          onCategoryChanged: (value) => _applyFilters(category: value),
          onCreateOffer: _openCreateOffer,
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _offersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _MarketplaceMessage(
                  message: marketplaceErrorMessage(
                    snapshot.error!,
                    fallbackKey: 'marketplace_load_failed',
                  ),
                  onRetry: _refreshOffers,
                );
              }
              final offers = snapshot.data ?? const <Map<String, dynamic>>[];
              if (offers.isEmpty) {
                return _MarketplaceMessage(
                  message: _showMyOffers
                      ? 'marketplace_empty_mine'.tr()
                      : 'marketplace_empty_all'.tr(),
                  onRetry: _refreshOffers,
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
    );
  }
}

class _MarketplaceMessage extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _MarketplaceMessage({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: kBodyTextStyle(size: 15, color: kInk.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text('refresh'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
