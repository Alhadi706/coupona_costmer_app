import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'offer_detail_screen.dart';
import '../services/company_server_service.dart';
import 'package:coupona_app/theme/design_tokens.dart';
import 'package:coupona_app/widgets/design_system/kupuna_offer_card.dart';

class CategoryOffersScreen extends StatelessWidget {
  final String categoryName;
  const CategoryOffersScreen({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('offers_for_category'.tr(namedArgs: {'category': categoryName.tr()})),
        backgroundColor: kTeal,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: Stream.periodic(const Duration(seconds: 6))
            .asyncMap((_) => CompanyServerService.getOffers(category: categoryName))
            .startWithFuture(CompanyServerService.getOffers(category: categoryName)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return Center(child: Text('no_offers_for_category'.tr()));
          }
          final offers = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              final offer = offers[index];
              final storeName = (offer['storeName'] ?? 'featured_offer'.tr()).toString();
              final offerType = (offer['offerType'] ?? '').toString();
              final percent = (offer['percent'] ?? '').toString();
              final endDate = (offer['endDate'] ?? '').toString();
              final location = (offer['location'] ?? '').toString();
              final String subtitle = <String>[
                if (offerType.isNotEmpty) offerType,
                if (percent.isNotEmpty) percent,
                if (endDate.isNotEmpty) 'ends_on'.tr(namedArgs: {'date': endDate}),
                if (location.isNotEmpty) location,
              ].join(' • ');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: KupunaOfferCard(
                  offer: <String, dynamic>{
                    ...offer,
                    'title': storeName,
                    'subtitle': subtitle.isEmpty ? categoryName.tr() : subtitle,
                    'sourceType': offer['sourceType'] ?? offer['ownerType'] ?? offer['type'] ?? '',
                  },
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetailScreen(offer: offer),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
