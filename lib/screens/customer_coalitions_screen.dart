import 'package:flutter/material.dart';

import '../dialogs/customer_redeem_coalition_gift_dialog.dart';
import '../services/company_server_service.dart';
import '../theme/design_tokens.dart';

class CustomerCoalitionsScreen extends StatefulWidget {
  const CustomerCoalitionsScreen({super.key});

  @override
  State<CustomerCoalitionsScreen> createState() => _CustomerCoalitionsScreenState();
}

class _CustomerCoalitionsScreenState extends State<CustomerCoalitionsScreen> {
  late Future<List<Map<String, dynamic>>> _coalitionsFuture;

  @override
  void initState() {
    super.initState();
    _coalitionsFuture = _loadCoalitions();
  }

  void _reload() {
    setState(() {
      _coalitionsFuture = _loadCoalitions();
    });
  }

  Future<List<Map<String, dynamic>>> _loadCoalitions() {
    return CompanyServerService.getMyCustomerCoalitions()
        .catchError((_) => const <Map<String, dynamic>>[]);
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  Future<void> _openGifts(Map<String, dynamic> coalition) async {
    final coalitionId = (coalition['id'] ?? '').toString();
    if (coalitionId.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => CustomerRedeemCoalitionGiftDialog(
        coalitionId: coalitionId,
        coalitionName: (coalition['name'] ?? 'ائتلاف').toString(),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSand,
      appBar: AppBar(
        title: const Text('شبكة الائتلافات'),
        backgroundColor: kTealDark,
        foregroundColor: kWhite,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _coalitionsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MessageCard(
                    icon: Icons.error_outline,
                    title: 'تعذر تحميل شبكة الائتلافات',
                    subtitle: snapshot.error.toString(),
                    action: TextButton(onPressed: _reload, child: const Text('إعادة المحاولة')),
                  ),
                ],
              );
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _MessageCard(
                    icon: Icons.hub_outlined,
                    title: 'لا توجد ائتلافات نشطة بعد',
                    subtitle: 'عند اكتسابك نقاطاً فضية أو ذهبية من شركاء الشبكة ستظهر هدايا الائتلاف هنا.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final points = _toInt(row['total_points'] ?? row['totalPoints']);
                final members = _toInt(row['merchant_count'] ?? row['merchantCount']);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const CircleAvatar(backgroundColor: kMint, child: Icon(Icons.hub_outlined, color: kTeal)),
                    title: Text((row['name'] ?? 'ائتلاف').toString(), style: kBodyTextStyle(weight: FontWeight.w900)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('$points نقطة متاحة عبر $members شريك', style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.72))),
                    ),
                    trailing: FilledButton.icon(
                      onPressed: () => _openGifts(row),
                      icon: const Icon(Icons.card_giftcard_outlined, size: 18),
                      label: const Text('الهدايا'),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.title, required this.subtitle, this.action});

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: kTeal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kBodyTextStyle(weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.72))),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
