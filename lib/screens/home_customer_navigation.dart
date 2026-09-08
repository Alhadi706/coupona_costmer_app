part of 'home_screen.dart';

Color _homeRoleColor(_HomeScreenState state) {
  switch (state._activeRole) {
    case 'admin':
      return kInk;
    default:
      return kTealDark;
  }
}

Widget _buildHomeBody(_HomeScreenState state) {
  final context = state.context;
  final customerTabs = _buildCustomerTabs(state);

  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Stack(
        children: [
          state._activeRole == 'customer'
              ? KeyedSubtree(
                  key: const ValueKey<String>('customer_mode_surface'),
                  child: customerTabs[state._selectedIndex],
                )
              : _buildRoleSurface(state),
          if (state._activeRole == 'customer' && state._selectedIndex == 0)
            Positioned(
              bottom: 16,
              right: context.locale.languageCode == 'ar' ? null : 16,
              left: context.locale.languageCode == 'ar' ? 16 : null,
              child: FloatingActionButton(
                heroTag: 'camera_scan_fab_unique_id',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ScanInvoiceScreen(),
                    ),
                  );
                },
                backgroundColor: kTeal,
                child: const Icon(Icons.camera_alt, color: kWhite),
              ),
            ),
        ],
      ),
    ),
  );
}

List<Widget> _buildCustomerTabs(_HomeScreenState state) {
  final context = state.context;

  return <Widget>[
    HomeContentScreen(
      onOpenOffersTab: () => state._onItemTapped(0),
      onOpenPeerAdsTab: () => state._onItemTapped(2),
      onOpenMap: () => state._onItemTapped(1),
      onOpenRewards: () => state._onItemTapped(3),
      onOpenCoalitions: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CustomerCoalitionsScreen()),
      ),
      onOpenCommunity: () =>
          state._openCommunityTab(CommunityHubTabs.marketplace),
      onOpenCustomerOffers: () =>
          state._openCommunityTab(CommunityHubTabs.marketplace),
      onScanReceipt: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ScanInvoiceScreen())),
    ),
    const FullMapScreen(embedded: true),
    CommunityScreen.embedded(tabRequest: state._communityTabRequest),
    const MyRewardsScreen.embedded(),
    const SettingsScreen.embedded(),
  ];
}

Widget _buildRoleSurface(_HomeScreenState state) {
  switch (state._activeRole) {
    case 'merchant':
      return const KeyedSubtree(
        key: ValueKey<String>('merchant_mode_surface'),
        child: MerchantDashboardScreen.embedded(),
      );
    case 'brand':
      return const KeyedSubtree(
        key: ValueKey<String>('brand_mode_surface'),
        child: BrandDashboardScreen.embedded(),
      );
    case 'cashier':
      return const KeyedSubtree(
        key: ValueKey<String>('cashier_mode_surface'),
        child: CashierDashboardScreen.embedded(),
      );
    case 'admin':
      return const KeyedSubtree(
        key: ValueKey<String>('admin_mode_surface'),
        child: AdminDashboardScreen.embedded(),
      );
    default:
      return const SizedBox.shrink();
  }
}

Widget? _buildCustomerBottomNavigationBar(_HomeScreenState state) {
  if (state._activeRole != 'customer') return null;

  return BottomNavigationBar(
    currentIndex: state._selectedIndex,
    onTap: state._onItemTapped,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: kTeal,
    unselectedItemColor: kInk.withValues(alpha: 0.6),
    backgroundColor: kWhite,
    items: [
      BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home),
        label: 'الرئيسية',
      ),
      BottomNavigationBarItem(
        icon: _buildNavIconWithBadge(Icons.map_outlined, state._mapBadgeCount),
        activeIcon: const Icon(Icons.map),
        label: 'الخريطة',
      ),
      BottomNavigationBarItem(
        icon: _buildNavIconWithBadge(
          Icons.groups_outlined,
          state._communityBadgeCount > 0
              ? state._communityBadgeCount
              : state._groupMessageUnread,
        ),
        activeIcon: const Icon(Icons.groups),
        label: 'المجتمعات والسوق',
      ),
      BottomNavigationBarItem(
        icon: _buildNavIconWithBadge(
          Icons.account_balance_wallet_outlined,
          state._rewardsBadgeCount,
        ),
        activeIcon: const Icon(Icons.account_balance_wallet),
        label: 'الجوائز',
      ),
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        activeIcon: const Icon(Icons.person),
        label: 'حسابي',
      ),
    ],
  );
}

Widget _buildNavIconWithBadge(IconData icon, int count) {
  if (count <= 0) {
    return Icon(icon);
  }
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(icon),
      Positioned(
        right: -8,
        top: -5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: const Color(0xFFE53935),
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          alignment: Alignment.center,
          child: Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ],
  );
}
