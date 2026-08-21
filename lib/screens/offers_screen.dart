import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'offer_detail_screen.dart';
import '../services/app_session.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class OffersScreen extends StatefulWidget {
  final bool embedded;

  const OffersScreen({super.key}) : embedded = false;

  const OffersScreen.embedded({super.key}) : embedded = true;

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _targetType = '';
  final TextEditingController _targetValueController = TextEditingController();
  final TextEditingController _minPointsController = TextEditingController();

  @override
  void dispose() {
    _targetValueController.dispose();
    _minPointsController.dispose();
    super.dispose();
  }

  Widget _buildOfferImage(String imageUrl) {
    final String trimmed = imageUrl.trim();
    final bool isAsset = trimmed.startsWith('assets/');
    if (trimmed.isEmpty) {
      return Container(
        height: 170,
        color: Colors.grey.shade200,
        child: const Icon(Icons.image_outlined, color: Colors.grey, size: 52),
      );
    }
    if (isAsset) {
      return Image.asset(
        trimmed,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    }
    return FutureBuilder<String?>(
      future: AppSession.token(),
      builder: (context, snapshot) => Image.network(
        trimmed,
        headers: snapshot.data == null ? null : {'Authorization': 'Bearer ${snapshot.data}'},
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 170,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 52),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadOffers() {
    final minPoints = int.tryParse(_minPointsController.text.trim());
    return CompanyServerService.getOffers(
      targetType: _targetType.isEmpty ? null : _targetType,
      targetValue: _targetValueController.text.trim().isEmpty ? null : _targetValueController.text.trim(),
      minPoints: minPoints,
    );
  }

  Widget _buildTargetingBar() {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Target Type',
                  border: OutlineInputBorder(),
                ),
                value: _targetType.isEmpty ? 'all' : _targetType,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'city', child: Text('City')),
                  DropdownMenuItem(value: 'country', child: Text('Country')),
                  DropdownMenuItem(value: 'min_points', child: Text('Min Points')),
                ],
                onChanged: (value) {
                  setState(() {
                    _targetType = value == null || value == 'all' ? '' : value;
                  });
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _targetValueController,
                decoration: const InputDecoration(
                  labelText: 'Target Value',
                  hintText: 'City/Country',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              width: 130,
              child: TextField(
                controller: _minPointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Min Points',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => setState(() {}),
              ),
            ),
            FilledButton(
              onPressed: () => setState(() {}),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOffersBody(BuildContext context) {
    return Column(
      children: [
        _buildTargetingBar(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Stream.periodic(const Duration(seconds: 5)).asyncMap((_) => _loadOffers()).startWithFuture(_loadOffers()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(child: Text('no_offers_available_now'.tr()));
              }
              final offers = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: offers.length,
                itemBuilder: (context, i) {
                  final offer = offers[i];
                  final imageUrl = (offer['imageUrl'] ?? offer['image'] ?? '').toString();
                  final storeName = (offer['storeName'] ?? 'عرض مميز').toString();
                  final offerType = (offer['offerType'] ?? '').toString();
                  final percent = (offer['percent'] ?? '').toString();
                  final endDate = (offer['endDate'] ?? '').toString();
                  final price = (offer['price'] ?? '').toString();
                  final location = (offer['location'] ?? '').toString();
                  final targetBadge = (offer['targetType'] ?? 'all').toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          child: Stack(
                            children: [
                              _buildOfferImage(imageUrl),
                              Positioned(
                                top: 10,
                                left: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    offerType.isEmpty ? 'offer'.tr() : offerType,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (percent.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: kSand,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        percent,
                                        style: TextStyle(
                                          color: kTealDark,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  if (endDate.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'ends_on'.tr(namedArgs: {'date': endDate}),
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      targetBadge,
                                      style: TextStyle(
                                        color: Colors.blue.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (price.isNotEmpty || location.isNotEmpty)
                                Row(
                                  children: [
                                    if (price.isNotEmpty)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.sell_outlined, size: 16, color: Colors.black54),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                price,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.black87),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (location.isNotEmpty)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined, size: 16, color: Colors.black54),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                location,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(color: Colors.black54),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kTeal,
                                    foregroundColor: kWhite,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => OfferDetailScreen(offer: offer),
                                      ),
                                    );
                                  },
                                  child: Text('view_details'.tr()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildOffersBody(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('available_offers_now_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: _buildOffersBody(context),
    );
  }
}

extension _StreamInit<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> first) async* {
    yield await first;
    yield* this;
  }
}
