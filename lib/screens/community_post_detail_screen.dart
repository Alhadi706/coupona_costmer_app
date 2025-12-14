import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/discover_feed.dart';
import 'merchant/merchant_public_profile_screen.dart';

class CommunityPostDetailScreen extends StatelessWidget {
  const CommunityPostDetailScreen({super.key, required this.post});

  final DiscoverFeedPost post;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(post.userName.isEmpty ? 'community_title'.tr() : post.userName),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 26,
              backgroundImage: post.userAvatar != null ? NetworkImage(post.userAvatar!) : null,
              child: post.userAvatar == null ? const Icon(Icons.person) : null,
            ),
            title: Text(post.userName.isEmpty ? 'community_title'.tr() : post.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat.yMMMMd().add_jm().format(post.createdAt)),
          ),
          const SizedBox(height: 12),
          if (post.merchantName.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.store, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Expanded(child: Text(post.merchantName, style: const TextStyle(fontWeight: FontWeight.w600))),
                if ((post.merchantId ?? '').isNotEmpty)
                  TextButton(
                    onPressed: () => _openMerchant(context),
                    child: Text('community_view_merchant'.tr()),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (post.images.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                post.images.first,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 240,
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            children: [
              Chip(avatar: const Icon(Icons.favorite, size: 18, color: Colors.pink), label: Text('${post.likes}')),
              Chip(avatar: const Icon(Icons.chat, size: 18, color: Colors.blueAccent), label: Text('${post.comments}')),
              Chip(avatar: const Icon(Icons.share, size: 18, color: Colors.green), label: Text('${post.shares}')),
            ],
          ),
          if (post.categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: post.categories.map((tag) => Chip(label: Text(tag))).toList(),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  void _openMerchant(BuildContext context) {
    if ((post.merchantId ?? '').isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantPublicProfileScreen(
          merchantId: post.merchantId!,
          placeholderName: post.merchantName,
        ),
      ),
    );
  }
}
