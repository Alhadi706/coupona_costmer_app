import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'coalitions/coalition_clearinghouse_screen.dart';
import 'coalitions/coalition_dashboard_screen.dart';
import 'merchant_gift_trigger.dart';
import 'public_coalition_membership_screen.dart';

class MerchantNetworksScreen extends StatelessWidget {
  const MerchantNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_nav_networks'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.public, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'coalition_public_header'.tr(),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('coalition_public_description'.tr()),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PublicCoalitionMembershipScreen(applicantType: 'merchant'),
                      ),
                    ),
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text('coalition_public_activate_button'.tr()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _NetworkDestination(
            icon: Icons.groups_2_outlined,
            title: 'merchant_nav_coalitions'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoalitionDashboardScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _NetworkDestination(
            icon: Icons.account_balance_wallet_outlined,
            title: 'merchant_nav_clearinghouse'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoalitionClearinghouseScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _NetworkDestination(
            icon: Icons.card_giftcard_outlined,
            title: 'merchant_nav_gifting'.tr(),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MerchantGiftTrigger()),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkDestination extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _NetworkDestination({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}