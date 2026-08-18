import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_offer_card.dart';

class OffersListScreen extends StatefulWidget {
  const OffersListScreen({super.key});

  @override
  State<OffersListScreen> createState() => _OffersListScreenState();
}

class _OffersListScreenState extends State<OffersListScreen> {
  late Future<List<Map<String, dynamic>>> _offersFuture;

  @override
  void initState() {
    super.initState();
    _offersFuture = fetchOffers();
  }

  Future<List<Map<String, dynamic>>> fetchOffers() async {
    try {
      return CompanyServerService.getOffers();
    } catch (e) {
      debugPrint('Fetch offers error: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('offers_list'.tr()),
        backgroundColor: kTealDark,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _offersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('generic_error_with_message'.tr(namedArgs: {'error': '${snapshot.error}'})));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('no_offers_available_now'.tr()));
          }
          final offers = snapshot.data!;
          return ListView.separated(
            itemCount: offers.length,
            padding: const EdgeInsets.all(12),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final offer = offers[index];
              return KupunaOfferCard(
                offer: <String, dynamic>{
                  ...offer,
                  'title': (offer['title'] ?? 'untitled_offer'.tr()).toString(),
                  'subtitle': (offer['description'] ?? '').toString(),
                },
              );
            },
          );
        },
      ),
    );
  }
}
