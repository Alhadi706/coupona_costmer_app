import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/company_server_service.dart';
import '../../services/marketplace_api_client.dart';
import '../../theme/design_tokens.dart';
import '../community_screen_widgets.dart';
import 'marketplace_categories.dart';

class CustomerOfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final Future<void> Function(Map<String, dynamic> offer, String status) onStatusChanged;
  final void Function(Map<String, dynamic> offer)? onContactSeller;

  const CustomerOfferCard({
    super.key,
    required this.offer,
    required this.onStatusChanged,
    this.onContactSeller,
  });

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    final str = rawDate.toString().trim();
    if (str.isEmpty) return '';
    try {
      final dt = DateTime.parse(str);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  Future<void> _launchPhone(BuildContext context, String rawPhone) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('phone_not_available'.tr())),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('action_failed'.tr(namedArgs: {'error': 'tel'}))),
      );
    }
  }

  Future<void> _launchWhatsApp(BuildContext context, String rawPhone, String offerTitle) async {
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('phone_not_available'.tr())),
      );
      return;
    }
    final text = 'مرحباً، أستفسر عن عرضك: $offerTitle';
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('action_failed'.tr(namedArgs: {'error': 'whatsapp'}))),
      );
    }
  }

  Future<void> _handleContactSeller(BuildContext context) async {
    if (onContactSeller != null) {
      onContactSeller!(offer);
      return;
    }

    final isOwner = offer['is_owner'] == true;
    if (isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('own_offer_notice'.tr())),
      );
      return;
    }

    final offerId = (offer['id'] ?? '').toString();
    final sellerName = (offer['seller_name'] ?? offer['publisher_name'] ?? 'marketplace_seller_fallback'.tr()).toString();
    final sellerId = (offer['customer_id'] ?? offer['seller_id'] ?? offer['publisher_id'] ?? '').toString();
    final title = (offer['title'] ?? '').toString();
    final price = (offer['price_lyd'] as num?)?.toDouble() ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      String? chatId;
      try {
        final res = await MarketplaceApiClient.contactSeller(offerId: offerId);
        chatId = res['chatId']?.toString();
      } catch (_) {}

      if ((chatId == null || chatId.isEmpty) && sellerId.isNotEmpty) {
        try {
          final chat = await CompanyServerService.createPrivateChat(
            targetUserId: sellerId,
            title: sellerName,
          );
          chatId = chat['id']?.toString();
        } catch (_) {}
      }

      if (!context.mounted) return;
      Navigator.of(context).pop();

      if (chatId == null || chatId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('cannot_start_chat'.tr())),
        );
        return;
      }

      final refMsg = 'استفسار بخصوص العرض: $title - السعر: ${price.toStringAsFixed(2)} ${'currency_lyd'.tr()}';

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(
            chatId: chatId!,
            title: sellerName,
            initialMessage: refMsg,
          ),
        ),
      );
    } catch (err) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('action_failed'.tr(namedArgs: {'error': err.toString()}))),
      );
    }
  }

  void _showOfferDetailSheet(BuildContext context) {
    final title = (offer['title'] ?? '').toString();
    final description = (offer['description'] ?? '').toString();
    final category = (offer['category'] ?? '').toString();
    final sellerRaw = (offer['seller_name'] ?? offer['publisher_name'] ?? '').toString();
    final seller = sellerRaw.isEmpty ? 'marketplace_seller_fallback'.tr() : sellerRaw;
    final phone = (offer['seller_phone'] ?? offer['publisher_phone'] ?? offer['phone'] ?? '').toString().trim();
    final price = (offer['price_lyd'] as num?)?.toDouble() ?? 0;
    final points = (offer['points_required'] as num?)?.toInt() ?? 0;
    final status = (offer['status'] ?? 'ACTIVE').toString();
    final isOwner = offer['is_owner'] == true;
    final createdAt = _formatDate(offer['created_at']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'offer_details_title'.tr(),
                        style: kBodyTextStyle(size: 18, weight: FontWeight.bold),
                      ),
                    ),
                    CustomerOfferStatusChip(status: status),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(title, style: kBodyTextStyle(size: 20, weight: FontWeight.bold, color: kTealDark)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(label: Text(marketplaceCategoryLabel(category))),
                    Chip(
                      avatar: const Icon(Icons.payments_outlined, size: 16, color: kTeal),
                      label: Text('${price.toStringAsFixed(2)} ${'currency_lyd'.tr()}'),
                    ),
                    if (offer['accepts_points_trade'] == true)
                      Chip(
                        avatar: const Icon(Icons.stars, size: 16, color: kGold),
                        label: Text('$points ${'points'.tr()}'),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: kTeal.withValues(alpha: 0.15),
                      child: const Icon(Icons.person, color: kTeal),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(seller, style: kBodyTextStyle(size: 15, weight: FontWeight.w700)),
                          if (createdAt.isNotEmpty)
                            Text(
                              '${'published_at'.tr()}: $createdAt',
                              style: kBodyTextStyle(size: 12, color: kInk.withValues(alpha: 0.6)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'offer_description_label'.tr(),
                  style: kBodyTextStyle(size: 14, weight: FontWeight.bold, color: kInk.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: kBodyTextStyle(size: 15, color: kInk.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (phone.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: () => _launchPhone(ctx, phone),
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text('direct_call'.tr()),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _launchWhatsApp(ctx, phone, title),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.green),
                        label: Text('whatsapp'.tr(), style: const TextStyle(color: Colors.green)),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: isOwner
                            ? null
                            : () {
                                Navigator.of(ctx).pop();
                                _handleContactSeller(context);
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: isOwner ? Colors.grey : kTeal,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.message),
                        label: Text(isOwner ? 'own_offer_notice'.tr() : 'contact_publisher_now'.tr()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (offer['title'] ?? '').toString();
    final description = (offer['description'] ?? '').toString();
    final category = (offer['category'] ?? '').toString();
    final sellerRaw = (offer['seller_name'] ?? offer['publisher_name'] ?? '').toString();
    final seller = sellerRaw.isEmpty ? 'marketplace_seller_fallback'.tr() : sellerRaw;
    final phone = (offer['seller_phone'] ?? offer['publisher_phone'] ?? offer['phone'] ?? '').toString().trim();
    final price = (offer['price_lyd'] as num?)?.toDouble() ?? 0;
    final points = (offer['points_required'] as num?)?.toInt() ?? 0;
    final status = (offer['status'] ?? 'ACTIVE').toString();
    final isOwner = offer['is_owner'] == true;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showOfferDetailSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined, color: kTeal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: kBodyTextStyle(size: 16, weight: FontWeight.w800)),
                  ),
                  CustomerOfferStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: kBodyTextStyle(size: 14, color: kInk.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text(marketplaceCategoryLabel(category))),
                  Chip(label: Text('${price.toStringAsFixed(2)} ${'currency_lyd'.tr()}')),
                  if (offer['accepts_points_trade'] == true)
                    Chip(
                      avatar: const Icon(Icons.stars, size: 16, color: kGold),
                      label: Text('$points ${'points'.tr()}'),
                    ),
                  if (!isOwner) Chip(avatar: const Icon(Icons.person_outline, size: 16), label: Text(seller)),
                ],
              ),
              if (isOwner && status == 'ACTIVE') ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => onStatusChanged(offer, 'ARCHIVED'),
                      child: Text('archive'.tr()),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: () => onStatusChanged(offer, 'SOLD'),
                      child: Text('offer_status_sold'.tr()),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (phone.isNotEmpty) ...[
                    OutlinedButton.icon(
                      onPressed: () => _launchPhone(context, phone),
                      icon: const Icon(Icons.phone_outlined, size: 16, color: kTeal),
                      label: Text('direct_call'.tr(), style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      onPressed: () => _launchWhatsApp(context, phone, title),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16, color: Colors.green),
                      label: Text('whatsapp'.tr(), style: const TextStyle(fontSize: 12, color: Colors.green)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: isOwner ? null : () => _handleContactSeller(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: isOwner ? Colors.grey : kTeal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.message_outlined, size: 16),
                    label: Text(
                      isOwner ? 'own_offer_notice'.tr() : 'message_publisher'.tr(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerOfferStatusChip extends StatelessWidget {
  final String status;

  const CustomerOfferStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'SOLD' => ('offer_status_sold'.tr(), Colors.green),
      'ARCHIVED' => ('offer_status_archived'.tr(), Colors.grey),
      _ => ('offer_status_active'.tr(), kTeal),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.25)),
    );
  }
}
