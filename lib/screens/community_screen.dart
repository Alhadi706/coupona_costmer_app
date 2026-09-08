import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../theme/design_tokens.dart';
import 'community_screen_widgets.dart';

class CommunityScreen extends StatefulWidget {
  final bool embedded;
  final String? initialGroupId;

  const CommunityScreen({super.key, this.initialGroupId}) : embedded = false;

  const CommunityScreen.embedded({super.key, this.initialGroupId}) : embedded = true;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        TabBarView(
          controller: _tabController,
          children: [
            CommunityGroupsTab(initialGroupId: widget.initialGroupId),
            CommunityPrivateChatsTab(),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: TabBar(
              controller: _tabController,
              labelColor: kTeal,
              unselectedLabelColor: kInk,
              indicatorColor: kGold,
              indicatorWeight: 3,
              indicator: BoxDecoration(
                color: kGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              tabs: [
                Tab(text: 'groups_tab'.tr(), icon: const Icon(Icons.groups)),
                Tab(text: 'private_messages_tab'.tr(), icon: const Icon(Icons.chat)),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('community_title'.tr()),
        backgroundColor: kTealDark,
      ),
      body: body,
    );
  }
}
