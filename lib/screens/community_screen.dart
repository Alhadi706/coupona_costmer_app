import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/community.dart';
import '../models/discover_feed.dart';
import '../services/firestore/discover_feed_repository.dart';
import '../services/merchant_community_service.dart';
import 'community_post_detail_screen.dart';
import 'merchant/merchant_public_profile_screen.dart';
import 'offer_detail_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final tabs = [
      'community_tab_discover'.tr(),
      'community_tab_groups'.tr(),
      'community_tab_trending'.tr(),
      'community_tab_notifications'.tr(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              indicatorColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(
                context,
              ).textTheme.bodyMedium?.color,
              tabs: tabs.map((label) => Tab(text: label)).toList(),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                DiscoverTab(userId: userId),
                MyGroupsTab(userId: userId),
                TrendingTab(userId: userId),
                CommunityNotificationsTab(userId: userId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoverTab extends StatefulWidget {
  const DiscoverTab({super.key, required this.userId});

  final String userId;

  @override
  State<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends State<DiscoverTab> {
  late final DiscoverFeedRepository _repository;
  late Stream<DiscoverFeedBundle> _feedStream;

  @override
  void initState() {
    super.initState();
    _repository = DiscoverFeedRepository();
    _feedStream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant DiscoverTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() => _feedStream = _buildStream());
    }
  }

  Stream<DiscoverFeedBundle> _buildStream() {
    final filter = DiscoverFeedFilter(
      userId: widget.userId,
      categories: const [],
    );
    return _repository.watchFeed(filter: filter, limit: 25);
  }

  Future<void> _refresh() async {
    setState(() => _feedStream = _buildStream());
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DiscoverFeedBundle>(
      stream: _feedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ErrorState(
            message: 'community_feed_error'.tr(),
            onRetry: _refresh,
          );
        }

        final bundle = snapshot.data;
        if (bundle == null) {
          return _EmptyState(onRefresh: _refresh);
        }

        final featuredPosts = bundle.posts.take(3).toList();
        final remainingPosts = bundle.posts.skip(3).toList();

        final children = <Widget>[
          if (bundle.spotlights.isNotEmpty) ...[
            _MerchantSpotlights(spotlights: bundle.spotlights),
            const SizedBox(height: 16),
          ],
          if (widget.userId.isNotEmpty) ...[
            _SuggestedGroups(userId: widget.userId),
            const SizedBox(height: 16),
          ] else ...[
            const _SignInPrompt(message: 'customer_analytics_sign_in'),
            const SizedBox(height: 16),
          ],
          if (featuredPosts.isNotEmpty) ...[
            _FeaturedPosts(posts: featuredPosts),
            const SizedBox(height: 16),
          ],
          if (bundle.exclusiveOffers.isNotEmpty) ...[
            _ExclusiveOffersSection(offers: bundle.exclusiveOffers),
            const SizedBox(height: 16),
          ],
          if (remainingPosts.isNotEmpty) _LatestPosts(posts: remainingPosts),
        ];

        if (children.isEmpty) {
          return _EmptyState(onRefresh: _refresh);
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: children,
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onRetry,
              child: Text('customer_analytics_retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(Icons.forum, size: 48, color: Colors.deepPurple.shade200),
          const SizedBox(height: 12),
          Text('community_no_messages'.tr(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class MyGroupsTab extends StatefulWidget {
  const MyGroupsTab({super.key, required this.userId});

  final String userId;

  @override
  State<MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<MyGroupsTab> {
  final TextEditingController _searchController = TextEditingController();
  final MerchantCommunityService _communityService = MerchantCommunityService();
  late Future<List<CommunityRoom>> _communitiesFuture;

  @override
  void initState() {
    super.initState();
    _communitiesFuture = _loadCommunities();
  }

  @override
  void didUpdateWidget(covariant MyGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() => _communitiesFuture = _loadCommunities());
    }
  }

  Future<List<CommunityRoom>> _loadCommunities() {
    if (widget.userId.isEmpty) {
      return Future.value(const <CommunityRoom>[]);
    }
    return _communityService.fetchAvailableRooms(widget.userId);
  }

  Future<void> _refreshCommunities() async {
    final future = _loadCommunities();
    setState(() => _communitiesFuture = future);
    await future;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) {
      return const _SignInPrompt(message: 'customer_analytics_sign_in');
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'community_search_groups'.tr(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCommunities,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FutureBuilder<List<CommunityRoom>>(
                  future: _communitiesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rooms = snapshot.data ?? const <CommunityRoom>[];
                    return _buildGroupSection(rooms);
                  },
                ),
                const SizedBox(height: 24),
                _buildPrivateMessagesSection(),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('coming_soon'.tr()))),
            icon: const Icon(Icons.add_circle_outline),
            label: Text('community_create_group'.tr()),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupSection(List<CommunityRoom> rooms) {
    final query = _searchController.text.toLowerCase();
    final filtered = rooms.where((room) {
      final name = room.name.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('community_no_groups'.tr()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filtered
          .map(
            (room) => Card(
              child: ListTile(
                leading: const Icon(Icons.groups, color: Colors.deepPurple),
                title: Text(room.name),
                subtitle: Text(room.description ?? ''),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _GroupChatScreen(
                      groupId: room.id,
                      groupName: room.name,
                      merchantId: room.merchantId,
                      userId: widget.userId,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildPrivateMessagesSection() {
    final stream = FirebaseFirestore.instance
        .collection('merchantCustomerRooms')
        .where('members', arrayContains: widget.userId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rooms =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (rooms.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('community_no_messages'.tr()),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'community_private_tab'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...rooms.map((room) {
              final data = room.data();
              final lastMessage =
                  data.containsKey('lastMessage') && data['lastMessage'] != null
                  ? data['lastMessage'].toString()
                  : 'community_no_messages'.tr();
              return _MerchantRoomTile(
                room: room,
                lastMessage: lastMessage,
                currentUserId: widget.userId,
              );
            }),
          ],
        );
      },
    );
  }
}

class _MerchantSpotlights extends StatelessWidget {
  const _MerchantSpotlights({required this.spotlights});

  final List<MerchantSpotlight> spotlights;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'community_spotlights'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: spotlights.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final spotlight = spotlights[index];
              final hasMerchant = spotlight.merchantId.isNotEmpty;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spotlight.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spotlight.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    FilledButton.tonal(
                      onPressed: hasMerchant
                          ? () => _openSpotlight(context, spotlight)
                          : null,
                      child: Text('community_view_merchant'.tr()),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openSpotlight(BuildContext context, MerchantSpotlight spotlight) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MerchantPublicProfileScreen(
          merchantId: spotlight.merchantId,
          placeholderName: spotlight.title,
          coverImage: spotlight.coverImage,
        ),
      ),
    );
  }
}

class _FeaturedPosts extends StatelessWidget {
  const _FeaturedPosts({required this.posts});

  final List<DiscoverFeedPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('community_no_messages'.tr()),
        ),
      );
    }
    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final post = posts[index];
          return Container(
            width: 260,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade400, Colors.pink.shade300],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    post.content,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likes}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.comments}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SuggestedGroups extends StatefulWidget {
  const _SuggestedGroups({required this.userId});

  final String userId;

  @override
  State<_SuggestedGroups> createState() => _SuggestedGroupsState();
}

class _SuggestedGroupsState extends State<_SuggestedGroups> {
  late Future<List<CommunityRoom>> _future;
  final MerchantCommunityService _service = MerchantCommunityService();

  @override
  void initState() {
    super.initState();
    _future = _service.fetchAvailableRooms(widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CommunityRoom>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = snapshot.data ?? const <CommunityRoom>[];
        if (groups.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('community_no_groups'.tr()),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'community_groups_tab'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...groups
                .take(3)
                .map(
                  (room) => Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.group)),
                      title: Text(room.name),
                      subtitle: Text(room.description ?? ''),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _GroupChatScreen(
                            groupId: room.id,
                            groupName: room.name,
                            merchantId: room.merchantId,
                            userId: widget.userId,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _LatestPosts extends StatelessWidget {
  const _LatestPosts({required this.posts});

  final List<DiscoverFeedPost> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(child: Text('community_no_messages'.tr()));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: posts.map((post) => _PostCard(post: post)).toList(),
    );
  }
}

class _ExclusiveOffersSection extends StatelessWidget {
  const _ExclusiveOffersSection({required this.offers});

  final List<ExclusiveOffer> offers;

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('community_no_messages'.tr()),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'offers_list'.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...offers.map(
          (offer) => Card(
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.deepPurple),
              title: Text(offer.storeName),
              subtitle: Text(offer.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfferDetailScreen(offer: offer.toMap()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final DiscoverFeedPost post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _openPostDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: post.userAvatar != null
                      ? NetworkImage(post.userAvatar!)
                      : null,
                ),
                title: Text(
                  post.userName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    const Icon(Icons.store, size: 14),
                    const SizedBox(width: 4),
                    Expanded(child: Text(post.merchantName)),
                    Text(
                      '${post.createdAt.hour}:${post.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'report', child: Text('report'.tr())),
                  ],
                ),
              ),
              Text(post.content),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    post.images.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.favorite_border),
                  ),
                  Text('${post.likes}'),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline),
                  ),
                  Text('${post.comments}'),
                  const Spacer(),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.share)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPostDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CommunityPostDetailScreen(post: post)),
    );
  }
}

class _MerchantRoomTile extends StatelessWidget {
  const _MerchantRoomTile({
    required this.room,
    required this.lastMessage,
    required this.currentUserId,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> room;
  final String lastMessage;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final data = room.data();
    final storedName = data['merchantName']?.toString();
    final merchantId = data['merchantId']?.toString() ?? '';
    if (storedName != null && storedName.isNotEmpty) {
      return _buildCard(context, storedName);
    }
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('merchants')
          .doc(merchantId)
          .get(),
      builder: (context, snapshot) {
        final fetchedName = snapshot.data?.data()?['name']?.toString() ?? '';
        final label = fetchedName.isNotEmpty ? fetchedName : merchantId;
        if (snapshot.connectionState == ConnectionState.done &&
            fetchedName.isNotEmpty &&
            (storedName == null || storedName.isEmpty)) {
          room.reference.update({'merchantName': fetchedName});
        }
        return _buildCard(context, label);
      },
    );
  }

  Widget _buildCard(BuildContext context, String merchantLabel) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.store, color: Colors.deepPurple),
        title: Text(merchantLabel),
        subtitle: Text(lastMessage),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _MerchantChatScreen(
                roomId: room.id,
                merchantName: merchantLabel,
                currentUserId: currentUserId,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MerchantChatScreen extends StatefulWidget {
  const _MerchantChatScreen({
    required this.roomId,
    required this.merchantName,
    required this.currentUserId,
  });

  final String roomId;
  final String merchantName;
  final String currentUserId;

  @override
  State<_MerchantChatScreen> createState() => _MerchantChatScreenState();
}

class _MerchantChatScreenState extends State<_MerchantChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, _ChatParticipant> _participants = {};
  String? _merchantId;

  @override
  void initState() {
    super.initState();
    _loadRoomParticipants();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomParticipants() async {
    try {
      final doc = await _firestore
          .collection('merchantCustomerRooms')
          .doc(widget.roomId)
          .get();
      final data = doc.data();
      if (data == null) {
        return;
      }
      final merchantId = data['merchantId']?.toString() ?? '';
      final customerId = data['customerId']?.toString() ?? widget.currentUserId;
      final merchantName = data['merchantName']?.toString();
      final merchantLogo = data['merchantLogo']?.toString();
      final customerName = data['customerName']?.toString();
      final customerAvatar = data['customerAvatar']?.toString();

      final participants = <String, _ChatParticipant>{};
      if (merchantId.isNotEmpty) {
        participants[merchantId] = _ChatParticipant(
          id: merchantId,
          displayName: (merchantName?.isNotEmpty == true
              ? merchantName!
              : widget.merchantName),
          avatarUrl: merchantLogo,
          isMerchant: true,
        );
      }
      if (customerId.isNotEmpty) {
        participants[customerId] = _ChatParticipant(
          id: customerId,
          displayName: (customerName?.isNotEmpty == true
              ? customerName!
              : 'You'),
          avatarUrl: customerAvatar,
          isCurrentUser: customerId == widget.currentUserId,
        );
      }

      setState(() {
        _participants = participants;
        _merchantId = merchantId;
      });

      if ((merchantName ?? '').isEmpty && merchantId.isNotEmpty) {
        _hydrateMerchantProfile(merchantId);
      }
      if ((customerName ?? '').isEmpty && customerId.isNotEmpty) {
        _hydrateCustomerProfile(customerId);
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to load chat participants: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateMerchantProfile(String merchantId) async {
    try {
      final doc = await _firestore
          .collection('merchants')
          .doc(merchantId)
          .get();
      final data = doc.data();
      if (data == null || !mounted) return;
      final current = _participants[merchantId];
      if (current == null) return;
      final name = data['name']?.toString();
      final logo = data['logoUrl']?.toString();
      setState(() {
        _participants[merchantId] = current.copyWith(
          displayName: name?.isNotEmpty == true ? name : null,
          avatarUrl: logo?.isNotEmpty == true ? logo : null,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Merchant profile fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _hydrateCustomerProfile(String customerId) async {
    try {
      final doc = await _firestore
          .collection('customers')
          .doc(customerId)
          .get();
      final data = doc.data();
      if (data == null || !mounted) return;
      final current = _participants[customerId];
      if (current == null) return;
      final name = data['name']?.toString();
      final avatar = data['photoUrl']?.toString();
      setState(() {
        _participants[customerId] = current.copyWith(
          displayName: name?.isNotEmpty == true ? name : null,
          avatarUrl: avatar?.isNotEmpty == true ? avatar : null,
        );
      });
    } catch (error, stackTrace) {
      debugPrint('Customer profile fetch failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final roomRef = _firestore
        .collection('merchantCustomerRooms')
        .doc(widget.roomId);
    await roomRef.collection('messages').add({
      'senderId': widget.currentUserId,
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await roomRef.update({
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = _firestore
        .collection('merchantCustomerRooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'community_chat_title_with'.tr(
            namedArgs: {'merchant': widget.merchantName},
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages =
                    snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (messages.isEmpty) {
                  return Center(child: Text('community_no_messages'.tr()));
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final senderId = data['senderId']?.toString() ?? '';
                    final isMe = senderId == widget.currentUserId;
                    final message = data['body']?.toString() ?? '';
                    final participant = _participantFor(senderId, isMe);
                    final reactions =
                        (data['reactions'] as Map<String, dynamic>?) ??
                        const <String, dynamic>{};
                    final likeCount = _countLikes(reactions);
                    final isLiked = _hasLiked(reactions);
                    return _ChatMessageTile(
                      participant: participant,
                      message: message,
                      isCurrentUser: isMe,
                      likeCount: likeCount,
                      isLiked: isLiked,
                      onToggleReaction: () =>
                          _toggleReaction(messages[index].reference, isLiked),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'community_chat_hint'.tr(),
                        border: const OutlineInputBorder(),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sendMessage,
                    child: Text('community_chat_send'.tr()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  _ChatParticipant _participantFor(String senderId, bool isMe) {
    final participant = _participants[senderId];
    if (participant != null) {
      return participant;
    }
    final isMerchant = senderId.isNotEmpty && senderId == _merchantId;
    final displayName = isMe
        ? 'You'
        : (isMerchant ? widget.merchantName : 'Member');
    return _ChatParticipant(
      id: senderId,
      displayName: displayName,
      isMerchant: isMerchant,
      isCurrentUser: isMe,
    );
  }

  int _countLikes(Map<String, dynamic> reactions) {
    var total = 0;
    for (final entry in reactions.values) {
      if (entry == 'like') {
        total++;
      }
    }
    return total;
  }

  bool _hasLiked(Map<String, dynamic> reactions) {
    return reactions[widget.currentUserId] == 'like';
  }

  Future<void> _toggleReaction(
    DocumentReference<Map<String, dynamic>> messageRef,
    bool isLiked,
  ) async {
    final fieldPath = 'reactions.${widget.currentUserId}';
    final payload = isLiked
        ? {fieldPath: FieldValue.delete()}
        : {fieldPath: 'like'};
    try {
      await messageRef.update(payload);
    } catch (error, stackTrace) {
      debugPrint('Failed to toggle merchant reaction: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}

class _GroupChatScreen extends StatefulWidget {
  const _GroupChatScreen({
    required this.groupId,
    required this.groupName,
    required this.merchantId,
    required this.userId,
  });

  final String groupId;
  final String groupName;
  final String merchantId;
  final String userId;

  @override
  State<_GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<_GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, _ChatParticipant> _participants = {};
  final Set<String> _pendingLookups = {};
  _ReplyContext? _replyContext;

  @override
  void initState() {
    super.initState();
    _primeMerchantProfile();
    _primeCurrentUserProfile();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final replyContext = _replyContext;
    await _firestore
        .collection('communities')
        .doc(widget.groupId)
        .collection('messages')
        .add({
          'senderId': widget.userId,
          'body': text,
          'createdAt': FieldValue.serverTimestamp(),
          if (replyContext != null) 'parentMessageId': replyContext.messageId,
          if (replyContext?.isPrivate == true &&
              replyContext?.targetUserId != null)
            'privateRecipients': <String>{
              widget.userId,
              replyContext!.targetUserId!,
            }.toList(),
        });
    _messageController.clear();
    setState(() => _replyContext = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('communities')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages =
                    snapshot.data?.docs ??
                    const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                if (messages.isEmpty) {
                  return Center(child: Text('community_no_messages'.tr()));
                }
                final messageIndex = <String, Map<String, dynamic>>{
                  for (final doc in messages) doc.id: doc.data(),
                };
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final docId = messages[index].id;
                    final senderId = data['senderId']?.toString() ?? '';
                    final isMe = senderId == widget.userId;
                    if (senderId.isNotEmpty &&
                        senderId != widget.merchantId &&
                        !_participants.containsKey(senderId)) {
                      _queueCustomerLookup(senderId);
                    }
                    final participant = _participantFor(senderId, isMe);
                    final reactions =
                        (data['reactions'] as Map<String, dynamic>?) ??
                        const <String, dynamic>{};
                    final likeCount = _countLikes(reactions);
                    final isLiked = _hasLiked(reactions);
                    final privateRecipients =
                        ((data['privateRecipients'] as List<dynamic>?)
                            ?.whereType<String>()
                            .toList()) ??
                        const <String>[];
                    final isPrivateMessage = privateRecipients.isNotEmpty;
                    final canSeePrivate =
                        !isPrivateMessage ||
                        privateRecipients.contains(widget.userId) ||
                        senderId == widget.userId;
                    if (!canSeePrivate) {
                      return const SizedBox.shrink();
                    }
                    final parentId = data['parentMessageId']?.toString();
                    final parentData = parentId != null
                        ? messageIndex[parentId]
                        : null;
                    final parentSenderId =
                        parentData?['senderId']?.toString() ?? '';
                    final parentParticipant = parentSenderId.isNotEmpty
                        ? _participantFor(
                            parentSenderId,
                            parentSenderId == widget.userId,
                          )
                        : null;
                    final parentBody = parentData?['body']?.toString();
                    return _ChatMessageTile(
                      messageId: docId,
                      participant: participant,
                      message: data['body']?.toString() ?? '',
                      isCurrentUser: isMe,
                      likeCount: likeCount,
                      isLiked: isLiked,
                      onToggleReaction: () =>
                          _toggleReaction(messages[index].reference, isLiked),
                      onReply: () => _startReply(
                        messageId: docId,
                        participant: participant,
                        message: data['body']?.toString() ?? '',
                        isPrivate: false,
                      ),
                      onPrivateReply:
                          (!isMe &&
                              (!isPrivateMessage ||
                                  privateRecipients.contains(widget.userId)))
                          ? () => _startReply(
                              messageId: docId,
                              participant: participant,
                              message: data['body']?.toString() ?? '',
                              isPrivate: true,
                            )
                          : null,
                      parentSenderName: parentParticipant?.displayName,
                      parentBody: parentBody,
                      isPrivate: isPrivateMessage,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'community_write_message'.tr(),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _primeMerchantProfile() {
    if (widget.merchantId.isEmpty) return;
    _firestore
        .collection('merchants')
        .doc(widget.merchantId)
        .get()
        .then((doc) {
          final data = doc.data();
          final name = data?['name']?.toString();
          final logo = data?['logoUrl']?.toString();
          if (!mounted) return;
          setState(() {
            _participants[widget.merchantId] = _ChatParticipant(
              id: widget.merchantId,
              displayName: (name?.isNotEmpty == true
                  ? name!
                  : widget.groupName),
              avatarUrl: logo,
              isMerchant: true,
            );
          });
        })
        .catchError((error, stackTrace) {
          debugPrint('Failed to load merchant profile: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _participants[widget.merchantId] = _ChatParticipant(
              id: widget.merchantId,
              displayName: widget.groupName,
              isMerchant: true,
            );
          });
        });
  }

  void _primeCurrentUserProfile() {
    if (widget.userId.isEmpty) return;
    setState(() {
      _participants[widget.userId] = _ChatParticipant(
        id: widget.userId,
        displayName: 'You',
        isCurrentUser: true,
      );
    });
    _queueCustomerLookup(widget.userId);
  }

  void _queueCustomerLookup(String userId) {
    if (_pendingLookups.contains(userId) || userId.isEmpty) {
      return;
    }
    if (userId == widget.merchantId) return;
    _pendingLookups.add(userId);
    _firestore
        .collection('customers')
        .doc(userId)
        .get()
        .then((doc) {
          final data = doc.data();
          final name = data?['name']?.toString();
          final avatar = data?['photoUrl']?.toString();
          if (!mounted) return;
          setState(() {
            final existing = _participants[userId];
            if (existing != null) {
              _participants[userId] = existing.copyWith(
                displayName: name?.isNotEmpty == true ? name : null,
                avatarUrl: avatar?.isNotEmpty == true ? avatar : null,
              );
            } else {
              _participants[userId] = _ChatParticipant(
                id: userId,
                displayName: name?.isNotEmpty == true ? name! : 'Member',
                avatarUrl: avatar,
              );
            }
          });
        })
        .catchError((error, stackTrace) {
          debugPrint('Customer profile lookup failed: $error');
          debugPrintStack(stackTrace: stackTrace);
          if (!mounted) return;
          setState(() {
            _participants[userId] =
                _participants[userId] ??
                _ChatParticipant(id: userId, displayName: 'Member');
          });
        })
        .whenComplete(() {
          _pendingLookups.remove(userId);
        });
  }

  _ChatParticipant _participantFor(String senderId, bool isMe) {
    final participant = _participants[senderId];
    if (participant != null) {
      return participant;
    }
    final isMerchant = senderId == widget.merchantId;
    return _ChatParticipant(
      id: senderId,
      displayName: isMe ? 'You' : (isMerchant ? widget.groupName : 'Member'),
      isMerchant: isMerchant,
      isCurrentUser: isMe,
    );
  }

  int _countLikes(Map<String, dynamic> reactions) {
    var total = 0;
    for (final entry in reactions.values) {
      if (entry == 'like') {
        total++;
      }
    }
    return total;
  }

  bool _hasLiked(Map<String, dynamic> reactions) {
    final value = reactions[widget.userId];
    return value == 'like';
  }

  Future<void> _toggleReaction(
    DocumentReference<Map<String, dynamic>> messageRef,
    bool isLiked,
  ) async {
    final fieldPath = 'reactions.${widget.userId}';
    final payload = isLiked
        ? {fieldPath: FieldValue.delete()}
        : {fieldPath: 'like'};
    try {
      await messageRef.update(payload);
    } catch (error, stackTrace) {
      debugPrint('Failed to toggle reaction: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startReply({
    required String messageId,
    required _ChatParticipant participant,
    required String message,
    required bool isPrivate,
  }) {
    setState(() {
      _replyContext = _ReplyContext(
        messageId: messageId,
        previewText: message,
        targetDisplayName: participant.displayName,
        targetUserId: isPrivate ? participant.id : null,
        isPrivate: isPrivate,
      );
    });
  }
}

class _ChatParticipant {
  const _ChatParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isMerchant = false,
    this.isCurrentUser = false,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isMerchant;
  final bool isCurrentUser;

  String get initials {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  _ChatParticipant copyWith({String? displayName, String? avatarUrl}) {
    return _ChatParticipant(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMerchant: isMerchant,
      isCurrentUser: isCurrentUser,
    );
  }
}

class _ReplyContext {
  const _ReplyContext({
    required this.messageId,
    required this.previewText,
    required this.targetDisplayName,
    this.targetUserId,
    required this.isPrivate,
  });

  final String messageId;
  final String previewText;
  final String targetDisplayName;
  final String? targetUserId;
  final bool isPrivate;
}

class _ReplyComposerBanner extends StatelessWidget {
  const _ReplyComposerBanner({
    required this.contextInfo,
    required this.onCancel,
  });

  final _ReplyContext contextInfo;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            contextInfo.isPrivate ? Icons.lock_outline : Icons.reply,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contextInfo.targetDisplayName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contextInfo.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ChatMessageTile extends StatelessWidget {
  const _ChatMessageTile({
    this.messageId,
    required this.participant,
    required this.message,
    required this.isCurrentUser,
    this.likeCount = 0,
    this.isLiked = false,
    this.onToggleReaction,
    this.onReply,
    this.onPrivateReply,
    this.parentSenderName,
    this.parentBody,
    this.isPrivate = false,
  });

  final String? messageId;
  final _ChatParticipant participant;
  final String message;
  final bool isCurrentUser;
  final int likeCount;
  final bool isLiked;
  final VoidCallback? onToggleReaction;
  final VoidCallback? onReply;
  final VoidCallback? onPrivateReply;
  final String? parentSenderName;
  final String? parentBody;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = participant.displayName.isNotEmpty
        ? participant.displayName
        : (participant.isCurrentUser
              ? 'You'
              : (participant.isMerchant ? 'Merchant' : 'Member'));
    final bubbleColor = isCurrentUser
        ? colorScheme.primary
        : colorScheme.surfaceVariant;
    final textColor = isCurrentUser ? Colors.white : colorScheme.onSurface;
    final alignment = isCurrentUser
        ? MainAxisAlignment.end
        : MainAxisAlignment.start;
    final crossAxisAlignment = isCurrentUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: alignment,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser) ...[
              _ChatAvatar(participant: participant, isCurrentUser: false),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (parentSenderName != null || parentBody != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isCurrentUser
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (parentSenderName != null)
                                  Text(
                                    parentSenderName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: colorScheme.outline),
                                  ),
                                if (parentBody != null)
                                  Text(
                                    parentBody!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: textColor),
                                  ),
                              ],
                            ),
                          ),
                        Text(message, style: TextStyle(color: textColor)),
                      ],
                    ),
                  ),
                  if (onToggleReaction != null ||
                      onReply != null ||
                      onPrivateReply != null ||
                      isPrivate)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: isCurrentUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          if (onToggleReaction != null)
                            _ReactionButton(
                              onTap: onToggleReaction!,
                              isLiked: isLiked,
                              likeCount: likeCount,
                            ),
                          if (isPrivate)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Chip(
                                label: Text('community_private_tab'.tr()),
                                avatar: const Icon(Icons.lock, size: 16),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          if (onReply != null)
                            IconButton(
                              icon: const Icon(Icons.reply),
                              visualDensity: VisualDensity.compact,
                              iconSize: 20,
                              tooltip: 'Reply',
                              onPressed: onReply,
                            ),
                          if (onPrivateReply != null)
                            IconButton(
                              icon: const Icon(Icons.lock_outline),
                              visualDensity: VisualDensity.compact,
                              iconSize: 18,
                              tooltip: 'Private reply',
                              onPressed: onPrivateReply,
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              _ChatAvatar(participant: participant, isCurrentUser: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({required this.participant, required this.isCurrentUser});

  final _ChatParticipant participant;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = participant.avatarUrl;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    final backgroundColor = hasImage
        ? null
        : (participant.isMerchant
              ? Colors.deepPurple.shade100
              : (isCurrentUser
                    ? colorScheme.primary.withOpacity(0.2)
                    : colorScheme.surfaceVariant));
    final foregroundColor = participant.isMerchant
        ? Colors.deepPurple
        : colorScheme.onSurfaceVariant;

    return CircleAvatar(
      radius: 18,
      backgroundColor: backgroundColor,
      backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
      child: hasImage
          ? null
          : Text(
              participant.initials,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.onTap,
    required this.isLiked,
    required this.likeCount,
  });

  final VoidCallback onTap;
  final bool isLiked;
  final int likeCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLiked ? Icons.favorite : Icons.favorite_border,
              size: 18,
              color: isLiked ? colorScheme.primary : colorScheme.outline,
            ),
            if (likeCount > 0) ...[
              const SizedBox(width: 6),
              Text(
                likeCount.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isLiked
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TrendingTab extends StatelessWidget {
  const TrendingTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('community_posts')
        .orderBy('createdAt', descending: true)
        .limit(40)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return Center(child: Text('community_no_messages'.tr()));
        }
        final posts = docs.map(DiscoverFeedPost.fromDoc).toList()
          ..sort((a, b) {
            final aScore = a.likes + (a.comments * 2) + (a.shares * 3);
            final bScore = b.likes + (b.comments * 2) + (b.shares * 3);
            return bScore.compareTo(aScore);
          });
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) => _PostCard(post: posts[index]),
        );
      },
    );
  }
}

class CommunityNotificationsTab extends StatelessWidget {
  const CommunityNotificationsTab({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return const _SignInPrompt(message: 'customer_analytics_sign_in');
    }
    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs =
            snapshot.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        if (docs.isEmpty) {
          return Center(child: Text('community_no_notifications'.tr()));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final createdAt = data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now();
            return Card(
              child: ListTile(
                leading: const Icon(
                  Icons.notifications_active,
                  color: Colors.deepPurple,
                ),
                title: Text(data['title']?.toString() ?? ''),
                subtitle: Text(data['body']?.toString() ?? ''),
                trailing: Text(
                  '${createdAt.month}/${createdAt.day}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message.tr(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
