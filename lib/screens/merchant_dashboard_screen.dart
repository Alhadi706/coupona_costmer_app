import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../models/invoice.dart';
import '../models/merchant.dart';
import '../models/reward.dart';
import '../services/firestore/customer_repository.dart';
import '../services/firestore/invoice_repository.dart';
import '../services/firestore/merchant_repository.dart';
import '../services/firestore/notification_repository.dart';
import '../services/firestore/product_repository.dart';
import '../services/firestore/reward_repository.dart';
import '../widgets/merchant_code_banner.dart';
import 'merchant/merchant_analytics_screen.dart';
import 'merchant/merchant_cashiers_screen.dart';
import 'merchant/merchant_community_screen.dart';
import 'merchant/merchant_customers_screen.dart';
import 'merchant/merchant_invoices_screen.dart';
import 'merchant/merchant_notifications_screen.dart';
import 'merchant/merchant_offers_screen.dart';
import 'merchant/merchant_points_settings_screen.dart';
import 'merchant/merchant_loyalty_rules_screen.dart';
import 'merchant/merchant_private_messages_screen.dart';
import 'merchant/merchant_products_screen.dart';
import 'merchant/merchant_rewards_screen.dart';
import 'merchant/merchant_reward_scanner_screen.dart';

class MerchantDashboardScreen extends StatefulWidget {
  final String merchantId;
  final String? successMessageKey;
  const MerchantDashboardScreen({
    super.key,
    required this.merchantId,
    this.successMessageKey,
  });

  @override
  State<MerchantDashboardScreen> createState() =>
      _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  late final MerchantRepository _merchantRepository;
  late final ProductRepository _productRepository;
  late final RewardRepository _rewardRepository;
  late final InvoiceRepository _invoiceRepository;
  late final CustomerRepository _customerRepository;
  late final NotificationRepository _notificationRepository;

  late final Stream<Merchant?> _merchantStream;
  late final Stream<List<Invoice>> _invoiceStream;
  late final Stream<List<Reward>> _rewardStream;
  late final Stream<int> _productCountStream;
  late final Stream<int> _pendingInvoiceCountStream;
  late final Stream<int> _activeRewardsCountStream;
  late final Stream<int> _visitorCountStream;
  late final Stream<int> _unreadNotificationsStream;

  int _selectedNavIndex = _navItems.length - 1;

  static const _quickActions = <_MerchantQuickAction>[
    _MerchantQuickAction(
      icon: Icons.campaign_outlined,
      color: Colors.deepOrange,
      labelKey: 'merchant_dashboard_offers',
      section: _MerchantSection.offers,
    ),
    _MerchantQuickAction(
      icon: Icons.analytics_outlined,
      color: Colors.deepPurple,
      labelKey: 'merchant_dashboard_analytics',
      section: _MerchantSection.analytics,
    ),
    _MerchantQuickAction(
      icon: Icons.stars_outlined,
      color: Colors.indigo,
      labelKey: 'merchant_points_settings_title',
      section: _MerchantSection.loyaltyRules,
    ),
    _MerchantQuickAction(
      icon: Icons.forum_outlined,
      color: Colors.teal,
      labelKey: 'merchant_settings_community',
      section: _MerchantSection.community,
    ),
    _MerchantQuickAction(
      icon: Icons.badge_outlined,
      color: Colors.pinkAccent,
      labelKey: 'merchant_settings_cashiers',
      section: _MerchantSection.cashiers,
    ),
    _MerchantQuickAction(
      icon: Icons.qr_code_scanner,
      color: Colors.green,
      labelKey: 'merchant_reward_scanner_title',
      section: _MerchantSection.rewardScanner,
    ),
    _MerchantQuickAction(
      icon: Icons.notifications_active_outlined,
      color: Colors.brown,
      labelKey: 'merchant_settings_notifications',
      section: _MerchantSection.notifications,
    ),
    _MerchantQuickAction(
      icon: Icons.settings_suggest_outlined,
      color: Colors.blueGrey,
      labelKey: 'merchant_dashboard_settings',
      section: _MerchantSection.settings,
    ),
  ];

  static const _navItems = <_MerchantNavItem>[
    _MerchantNavItem(
      icon: Icons.receipt_long_outlined,
      labelKey: 'merchant_nav_receipts',
      section: _MerchantSection.invoices,
    ),
    _MerchantNavItem(
      icon: Icons.shopping_bag_outlined,
      labelKey: 'merchant_nav_products',
      section: _MerchantSection.products,
    ),
    _MerchantNavItem(
      icon: Icons.groups_outlined,
      labelKey: 'merchant_nav_visitors',
      section: _MerchantSection.visitors,
    ),
    _MerchantNavItem(
      icon: Icons.local_offer_outlined,
      labelKey: 'merchant_nav_offers',
      section: _MerchantSection.offers,
    ),
    _MerchantNavItem(
      icon: Icons.bar_chart_outlined,
      labelKey: 'merchant_nav_home',
      section: _MerchantSection.home,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _merchantRepository = MerchantRepository();
    _productRepository = ProductRepository();
    _rewardRepository = RewardRepository();
    _customerRepository = CustomerRepository();
    _invoiceRepository = InvoiceRepository(
      customerRepository: _customerRepository,
    );
    _notificationRepository = NotificationRepository();

    _merchantStream = _merchantRepository.watchMerchant(widget.merchantId);
    _invoiceStream = _invoiceRepository.watchInvoices(widget.merchantId);
    _rewardStream = _rewardRepository.watchRewards(widget.merchantId);
    _productCountStream = _productRepository
        .watchProducts(widget.merchantId)
        .map((items) => items.length);
    _pendingInvoiceCountStream = _invoiceStream.map(
      (invoices) => invoices.where((i) => i.status == 'pending').length,
    );
    _activeRewardsCountStream = _rewardStream.map(
      (rewards) => rewards.where((r) => r.isActive).length,
    );
    _visitorCountStream = _customerRepository
        .watchCustomersForMerchant(widget.merchantId)
        .map((customers) => customers.length);
    _unreadNotificationsStream = _notificationRepository
        .watchNotifications(widget.merchantId)
        .map((notifications) => notifications.where((n) => !n.isRead).length);

    if (widget.successMessageKey != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(widget.successMessageKey!.tr())));
      });
    }
  }

  void _handleNavTap(int index) {
    setState(() => _selectedNavIndex = index);
    final item = _navItems[index];
    if (item.section == _MerchantSection.home) return;
    _openSection(item.section);
  }

  void _openSection(_MerchantSection section) {
    late final Widget screen;
    switch (section) {
      case _MerchantSection.products:
        screen = MerchantProductsScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.offers:
        screen = MerchantOffersScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.invoices:
        screen = MerchantInvoicesScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.visitors:
        screen = MerchantCustomersScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.rewards:
        screen = MerchantRewardsScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.analytics:
        screen = MerchantAnalyticsScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.settings:
        _showSettingsSheet();
        return;
      case _MerchantSection.pointsSettings:
        screen = MerchantPointsSettingsScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.loyaltyRules:
        screen = MerchantLoyaltyRulesScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.messages:
        screen = MerchantPrivateMessagesScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.cashiers:
        screen = MerchantCashiersScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.community:
        screen = MerchantCommunityScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.notifications:
        screen = MerchantNotificationsScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.rewardScanner:
        screen = MerchantRewardScannerScreen(merchantId: widget.merchantId);
        break;
      case _MerchantSection.home:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.stars_outlined),
              title: Text('merchant_points_settings_title'.tr()),
              subtitle: Text('merchant_points_settings_description'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _openSection(_MerchantSection.pointsSettings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text('merchant_settings_cashiers'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _openSection(_MerchantSection.cashiers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text('merchant_settings_community'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _openSection(_MerchantSection.community);
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text('merchant_settings_notifications'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _openSection(_MerchantSection.notifications);
              },
            ),
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text('merchant_settings_messages'.tr()),
              subtitle: Text('merchant_settings_messages_subtitle'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _openSection(_MerchantSection.messages);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF2EEFF),
      appBar: AppBar(
        title: Text(
          'merchant_dashboard_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF4A2CCE),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          StreamBuilder<int>(
            stream: _unreadNotificationsStream,
            builder: (context, snapshot) {
              final unread = snapshot.data ?? 0;
              return IconButton(
                icon: Stack(
                  children: [
                    const Icon(Icons.notifications_none),
                    if (unread > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () => _openSection(_MerchantSection.notifications),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF9F7FF), Color(0xFFEFE9FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StreamBuilder<Merchant?>(
                stream: _merchantStream,
                builder: (context, snapshot) {
                  final merchant = snapshot.data;
                  final widgets = <Widget>[
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.deepPurple.shade50,
                              child: const Icon(
                                Icons.store_outlined,
                                color: Colors.deepPurple,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    merchant?.name ??
                                        'merchant_dashboard_title'.tr(),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if ((merchant?.email ?? '').isNotEmpty)
                                    Text(
                                      merchant!.email,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  if ((merchant?.phone ?? '').isNotEmpty)
                                    Text(
                                      merchant!.phone,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];

                  final code = merchant?.merchantCode ?? '';
                  if (code.isNotEmpty) {
                    widgets.add(const SizedBox(height: 12));
                    widgets.add(MerchantCodeBanner(merchantCode: code));
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: widgets,
                  );
                },
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'merchant_dashboard_shortcuts_title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'merchant_dashboard_shortcuts_subtitle'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickActionsGrid(
                        quickActions: _quickActions,
                        onTap: _openSection,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'merchant_dashboard_overview_title'.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'merchant_dashboard_overview_subtitle'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DashboardMetrics(
                        productCountStream: _productCountStream,
                        pendingInvoiceCountStream: _pendingInvoiceCountStream,
                        activeRewardsCountStream: _activeRewardsCountStream,
                        visitorCountStream: _visitorCountStream,
                        onTileTap: _openSection,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                titleKey: 'merchant_dashboard_recent_invoices',
                actionLabelKey: 'merchant_dashboard_view_all',
                onActionTap: () => _openSection(_MerchantSection.invoices),
                child: _RecentInvoicesList(stream: _invoiceStream),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                titleKey: 'merchant_dashboard_active_rewards',
                actionLabelKey: 'merchant_dashboard_view_all',
                onActionTap: () => _openSection(_MerchantSection.rewards),
                child: _ActiveRewardsList(stream: _rewardStream),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: _handleNavTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        items: _navItems
            .map(
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.labelKey.tr(),
              ),
            )
            .toList(),
      ),
    );
  }
}
 
class _QuickActionsGrid extends StatelessWidget {
  final List<_MerchantQuickAction> quickActions;
  final void Function(_MerchantSection) onTap;
  const _QuickActionsGrid({required this.quickActions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final targetColumns = width >= 900
            ? 4
            : width >= 600
            ? 3
            : 2;
        final tileWidth = (width - (targetColumns - 1) * 12) / targetColumns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: quickActions
              .map(
                (action) => SizedBox(
                  width: tileWidth,
                  child: _QuickActionCard(
                    action: action,
                    onTap: () => onTap(action.section),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
 
// Types used by the dashboard (kept as private to this file).
enum _MerchantSection {
  home,
  products,
  invoices,
  visitors,
  offers,
  rewards,
  analytics,
  settings,
  pointsSettings,
  loyaltyRules,
  messages,
  cashiers,
  community,
  notifications,
  rewardScanner,
}

class _MerchantQuickAction {
  final IconData icon;
  final Color color;
  final String labelKey;
  final _MerchantSection section;
  const _MerchantQuickAction({
    required this.icon,
    required this.color,
    required this.labelKey,
    required this.section,
  });
}

class _MerchantNavItem {
  final IconData icon;
  final String labelKey;
  final _MerchantSection section;
  const _MerchantNavItem({
    required this.icon,
    required this.labelKey,
    required this.section,
  });
}
class _QuickActionCard extends StatelessWidget {
  final _MerchantQuickAction action;
  final VoidCallback onTap;
  const _QuickActionCard({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = action.color;
    final isRtl = Directionality.of(context) == ui.TextDirection.rtl;
    final arrowIcon = isRtl ? Icons.chevron_left : Icons.chevron_right;
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w700,
      color: Colors.black.withValues(alpha: 0.85),
    );
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.2),
        highlightColor: color.withValues(alpha: 0.1),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.16),
                color.withValues(alpha: 0.07),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
                child: Icon(action.icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  action.labelKey.tr(),
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(arrowIcon, color: Colors.black54, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  final Stream<int> productCountStream;
  final Stream<int> pendingInvoiceCountStream;
  final Stream<int> activeRewardsCountStream;
  final Stream<int> visitorCountStream;
  final void Function(_MerchantSection) onTileTap;
  const _DashboardMetrics({
    required this.productCountStream,
    required this.pendingInvoiceCountStream,
    required this.activeRewardsCountStream,
    required this.visitorCountStream,
    required this.onTileTap,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MetricTileConfig(
        icon: Icons.shopping_cart_outlined,
        labelKey: 'merchant_dashboard_products',
        stream: productCountStream,
        section: _MerchantSection.products,
        color: const Color(0xFF7C4DFF),
      ),
      _MetricTileConfig(
        icon: Icons.schedule_outlined,
        labelKey: 'merchant_dashboard_pending_invoices',
        stream: pendingInvoiceCountStream,
        section: _MerchantSection.invoices,
        color: const Color(0xFFFF7043),
      ),
      _MetricTileConfig(
        icon: Icons.card_giftcard_outlined,
        labelKey: 'merchant_dashboard_rewards',
        stream: activeRewardsCountStream,
        section: _MerchantSection.rewards,
        color: const Color(0xFF26C6DA),
      ),
      _MetricTileConfig(
        icon: Icons.groups_outlined,
        labelKey: 'merchant_dashboard_visitors',
        stream: visitorCountStream,
        section: _MerchantSection.visitors,
        color: const Color(0xFFFFC107),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: tiles
          .map(
            (tile) =>
                _MetricTile(config: tile, onTap: () => onTileTap(tile.section)),
          )
          .toList(),
    );
  }
}

class _MetricTileConfig {
  final IconData icon;
  final String labelKey;
  final Stream<int> stream;
  final _MerchantSection section;
  final Color color;
  const _MetricTileConfig({
    required this.icon,
    required this.labelKey,
    required this.stream,
    required this.section,
    required this.color,
  });
}

class _MetricTile extends StatelessWidget {
  final _MetricTileConfig config;
  final VoidCallback onTap;
  const _MetricTile({required this.config, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: config.stream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final theme = Theme.of(context);
        final color = config.color;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            splashColor: color.withValues(alpha: 0.15),
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [Colors.white, color.withValues(alpha: 0.15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: color.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config.icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    count.toString(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    config.labelKey.tr(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String titleKey;
  final String actionLabelKey;
  final VoidCallback onActionTap;
  final Widget child;
  const _SectionCard({
    required this.titleKey,
    required this.actionLabelKey,
    required this.onActionTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  titleKey.tr(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: onActionTap,
                  child: Text(actionLabelKey.tr()),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _RecentInvoicesList extends StatelessWidget {
  final Stream<List<Invoice>> stream;
  const _RecentInvoicesList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Invoice>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final invoices = (snapshot.data ?? const []).take(5).toList();
        if (invoices.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('merchant_dashboard_no_data'.tr()),
          );
        }
        return Column(
          children: invoices
              .map(
                (invoice) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(invoice.invoiceNumber),
                  subtitle: Text(invoice.customerId),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(invoice.totalAmount.toStringAsFixed(2)),
                      Text('merchant_invoices_status_${invoice.status}'.tr()),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ActiveRewardsList extends StatelessWidget {
  final Stream<List<Reward>> stream;
  const _ActiveRewardsList({required this.stream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Reward>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final rewards = (snapshot.data ?? const [])
            .where((reward) => reward.isActive)
            .take(3)
            .toList();
        if (rewards.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('merchant_dashboard_no_data'.tr()),
          );
        }
        return Column(
          children: rewards
              .map(
                (reward) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(reward.title),
                  subtitle: Text(
                    'merchant_rewards_points_fmt'.tr(
                      args: [reward.requiredPoints.toString()],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

