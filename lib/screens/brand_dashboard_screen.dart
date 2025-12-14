import 'package:flutter/material.dart';

import '../models/brand.dart';
import '../models/brand_campaign.dart';
import '../models/brand_community_post.dart';
import '../models/brand_product.dart';
import '../models/brand_reward.dart';
import '../services/firestore/brand_content_repository.dart';
import '../services/firestore/brand_repository.dart';
import 'store_performance_analysis_screen.dart';

class BrandDashboardScreen extends StatefulWidget {
  final String brandId;

  const BrandDashboardScreen({super.key, required this.brandId});

  @override
  State<BrandDashboardScreen> createState() => _BrandDashboardScreenState();
}

class _BrandDashboardScreenState extends State<BrandDashboardScreen> with SingleTickerProviderStateMixin {
  final List<String> _tabs = const ['الرئيسية', 'المنتجات', 'المكافآت', 'الحملات', 'التحليلات', 'المجتمع', 'الإعدادات'];
  late final TabController _tabController;
  late final BrandRepository _brandRepository;
  late final BrandContentRepository _contentRepository;
  bool _hasUnreadNotifications = true;

  @override
  void initState() {
    super.initState();
    _brandRepository = BrandRepository();
    _contentRepository = BrandContentRepository();
    _tabController = TabController(length: _tabs.length, vsync: this)..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<Brand?>(
        stream: _brandRepository.watchBrand(widget.brandId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final brand = snapshot.data;
          if (brand == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('لوحة العلامة')),
              body: const Center(child: Text('لم يتم العثور على ملف العلامة')),
            );
          }
          return _buildBrandScaffold(brand);
        },
      ),
    );
  }

  Widget _buildBrandScaffold(Brand brand) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: brand.logoUrl != null && brand.logoUrl!.isNotEmpty ? NetworkImage(brand.logoUrl!) : null,
              child: brand.logoUrl == null || brand.logoUrl!.isEmpty ? const Icon(Icons.storefront) : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(brand.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('لوحة العلامة', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openNotifications,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (_hasUnreadNotifications)
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  ),
              ],
            ),
          ),
          IconButton(onPressed: () => _openProfile(brand), icon: const Icon(Icons.info_outline)),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          BrandHomeTab(
            brand: brand,
            brandId: widget.brandId,
            repository: _contentRepository,
            onCreateCommunityAction: (type) => _openCommunityComposer(type: type),
          ),
          ProductsTab(
            brandId: widget.brandId,
            repository: _contentRepository,
            onCreateProduct: ({BrandProduct? product}) => _openProductComposer(product: product),
          ),
          RewardsTab(
            brandId: widget.brandId,
            repository: _contentRepository,
            onCreateReward: ({BrandReward? reward}) => _openRewardComposer(reward: reward),
          ),
          CampaignsTab(brandId: widget.brandId, repository: _contentRepository),
          AnalyticsTab(brand: brand, brandId: widget.brandId, repository: _contentRepository),
          CommunityTab(brandId: widget.brandId, repository: _contentRepository, onCreatePost: (type) => _openCommunityComposer(type: type)),
          SettingsTab(brand: brand),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    switch (_tabController.index) {
      case 1:
        return FloatingActionButton.extended(onPressed: () => _openProductComposer(), icon: const Icon(Icons.add_box_outlined), label: const Text('منتج جديد'));
      case 2:
        return FloatingActionButton.extended(onPressed: _openRewardComposer, icon: const Icon(Icons.card_giftcard), label: const Text('مكافأة جديدة'));
      case 3:
        return FloatingActionButton.extended(onPressed: _openCampaignComposer, icon: const Icon(Icons.campaign_outlined), label: const Text('حملة جديدة'));
      case 5:
        return FloatingActionButton.extended(onPressed: () => _openCommunityComposer(type: 'منشور'), icon: const Icon(Icons.post_add), label: const Text('منشور مجتمع'));
      default:
        return null;
    }
  }

  void _openNotifications() {
    setState(() => _hasUnreadNotifications = false);
    showModalBottomSheet(
      context: context,
      builder: (context) => const Padding(
        padding: EdgeInsets.all(24),
        child: Text('سيتم إضافة مركز الإشعارات قريباً.'),
      ),
    );
  }

  void _openProfile(Brand brand) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 28,
                backgroundImage: brand.logoUrl != null && brand.logoUrl!.isNotEmpty ? NetworkImage(brand.logoUrl!) : null,
                child: brand.logoUrl == null || brand.logoUrl!.isEmpty ? const Icon(Icons.storefront) : null,
              ),
              title: Text(brand.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(brand.email),
            ),
            if (brand.description != null && brand.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('الوصف: ${brand.description}'),
              ),
            if (brand.contactNumber != null && brand.contactNumber!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('رقم التواصل: ${brand.contactNumber}'),
              ),
            if (brand.website != null && brand.website!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('الموقع الإلكتروني: ${brand.website}'),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('آخر تحديث: ${_formatDate(brand.updatedAt.toDate())}', style: const TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductComposer({BrandProduct? product}) async {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(text: product != null ? product.price.toStringAsFixed(2) : '');
    final pointsController = TextEditingController(text: product?.pointsPerUnit.toString() ?? '');
    final imageController = TextEditingController(text: product?.imageUrl ?? '');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BottomSheetScaffold(
        title: product == null ? 'إضافة منتج' : 'تعديل منتج',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم المنتج', prefixIcon: Icon(Icons.inventory_2_outlined))),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'السعر', prefixIcon: Icon(Icons.attach_money)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(labelText: 'النقاط لكل عملية', prefixIcon: Icon(Icons.confirmation_num_outlined)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(controller: imageController, decoration: const InputDecoration(labelText: 'رابط الصورة (اختياري)', prefixIcon: Icon(Icons.link_outlined))),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(product == null ? 'إضافة' : 'حفظ التعديلات')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال اسم المنتج')));
      return;
    }
    final price = double.tryParse(priceController.text.trim()) ?? 0;
    final points = int.tryParse(pointsController.text.trim()) ?? 0;
    final imageUrl = imageController.text.trim();

    try {
      if (product == null) {
        await _contentRepository.addProduct(
          brandId: widget.brandId,
          name: name,
          price: price,
          pointsPerUnit: points,
          imageUrl: imageUrl.isEmpty ? null : imageUrl,
        );
      } else {
        await _contentRepository.updateProduct(
          brandId: widget.brandId,
          productId: product.id,
          data: {
            'name': name,
            'price': price,
            'pointsPerUnit': points,
            if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          },
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنتج')));
      }
    } catch (error) {
      debugPrint('product composer error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ المنتج')));
      }
    }
  }

  Future<void> _openRewardComposer({BrandReward? reward}) async {
    final titleController = TextEditingController(text: reward?.title ?? '');
    final pointsController = TextEditingController(text: reward?.points.toString() ?? '');
    final statusController = TextEditingController(text: reward?.status ?? 'active');
    final startController = TextEditingController(text: _formatDate(reward?.startsAt.toDate() ?? DateTime.now()));
    final endController = TextEditingController(text: _formatDate(reward?.endsAt.toDate() ?? DateTime.now().add(const Duration(days: 30))));

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BottomSheetScaffold(
        title: reward == null ? 'إضافة مكافأة' : 'تعديل مكافأة',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'عنوان المكافأة', prefixIcon: Icon(Icons.card_giftcard))),
            const SizedBox(height: 12),
            TextField(
              controller: pointsController,
              decoration: const InputDecoration(labelText: 'النقاط المطلوبة', prefixIcon: Icon(Icons.confirmation_number)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(controller: statusController, decoration: const InputDecoration(labelText: 'الحالة (active/upcoming/expired)', prefixIcon: Icon(Icons.flag))),
            const SizedBox(height: 12),
            TextField(controller: startController, decoration: const InputDecoration(labelText: 'تاريخ البداية (YYYY-MM-DD)', prefixIcon: Icon(Icons.event_available))),
            const SizedBox(height: 12),
            TextField(controller: endController, decoration: const InputDecoration(labelText: 'تاريخ النهاية (YYYY-MM-DD)', prefixIcon: Icon(Icons.event_busy))),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(reward == null ? 'إضافة' : 'حفظ')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final points = int.tryParse(pointsController.text.trim()) ?? 0;
    final status = statusController.text.trim().isEmpty ? 'active' : statusController.text.trim();
    final startsAt = DateTime.tryParse(startController.text.trim()) ?? DateTime.now();
    final endsAt = DateTime.tryParse(endController.text.trim()) ?? DateTime.now().add(const Duration(days: 30));

    try {
      await _contentRepository.addReward(
        brandId: widget.brandId,
        title: titleController.text.trim(),
        points: points,
        status: status,
        startsAt: startsAt,
        endsAt: endsAt,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المكافأة')));
      }
    } catch (error) {
      debugPrint('reward composer error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ المكافأة')));
      }
    }
  }

  Future<void> _openCampaignComposer() async {
    final nameController = TextEditingController();
    final goalController = TextEditingController();
    final budgetController = TextEditingController();
    final statusController = TextEditingController(text: 'نشطة');

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BottomSheetScaffold(
        title: 'إطلاق حملة جديدة',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'اسم الحملة', prefixIcon: Icon(Icons.campaign_outlined))),
            const SizedBox(height: 12),
            TextField(controller: goalController, decoration: const InputDecoration(labelText: 'الهدف الرئيس', prefixIcon: Icon(Icons.flag_outlined))),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              decoration: const InputDecoration(labelText: 'الميزانية (دينار)', prefixIcon: Icon(Icons.attach_money)),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(controller: statusController, decoration: const InputDecoration(labelText: 'الحالة الحالية')),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('حفظ الحملة')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final status = statusController.text.trim().isEmpty ? 'نشطة' : statusController.text.trim();
    final budget = double.tryParse(budgetController.text.trim()) ?? 0;

    try {
      await _contentRepository.addCampaign(
        brandId: widget.brandId,
        name: nameController.text.trim(),
        status: status,
        budget: budget,
        goal: goalController.text.trim(),
      );
      if (status.contains('نش')) {
        await _brandRepository.incrementCounter(widget.brandId, 'runningCampaigns', 1);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الحملة')));
      }
    } catch (error) {
      debugPrint('campaign composer error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر حفظ الحملة')));
      }
    }
  }

  Future<void> _openCommunityComposer({required String type}) async {
    final contentController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _BottomSheetScaffold(
        title: 'إنشاء $type',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: contentController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'نص المنشور', prefixIcon: Icon(Icons.edit_note)),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('نشر في المجتمع')),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await _contentRepository.addCommunityPost(
        brandId: widget.brandId,
        type: type,
        content: contentController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نشر المحتوى')));
      }
    } catch (error) {
      debugPrint('community composer error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر نشر المحتوى')));
      }
    }
  }
}

class BrandHomeTab extends StatelessWidget {
  final Brand brand;
  final String brandId;
  final BrandContentRepository repository;
  final ValueChanged<String> onCreateCommunityAction;

  const BrandHomeTab({super.key, required this.brand, required this.brandId, required this.repository, required this.onCreateCommunityAction});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BrandSummaryCard(brand: brand),
        const SizedBox(height: 16),
        _BrandMetrics(brand: brand),
        const SizedBox(height: 16),
        _LatestProductsPreview(repository: repository, brandId: brandId),
        const SizedBox(height: 16),
        _LatestRewardsPreview(repository: repository, brandId: brandId),
        const SizedBox(height: 16),
        _LatestCampaignsPreview(repository: repository, brandId: brandId),
        const SizedBox(height: 16),
        _CommunityPulseCard(repository: repository, brandId: brandId, onCreateCommunityAction: onCreateCommunityAction),
      ],
    );
  }
}

class _BrandSummaryCard extends StatelessWidget {
  final Brand brand;
  const _BrandSummaryCard({required this.brand});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مرحباً ${brand.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('تم إنشاء الحساب في ${_formatDate(brand.createdAt.toDate())}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Row(
              children: [
                _SummaryMetric(label: 'المنتجات', value: brand.totalProducts.toString(), icon: Icons.inventory_2_outlined),
                const SizedBox(width: 12),
                _SummaryMetric(label: 'المكافآت', value: brand.activeRewards.toString(), icon: Icons.card_giftcard),
                const SizedBox(width: 12),
                _SummaryMetric(label: 'الحملات', value: brand.runningCampaigns.toString(), icon: Icons.campaign_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.grey.shade200),
        child: Column(
          children: [
            Icon(icon, color: Colors.blueGrey),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _BrandMetrics extends StatelessWidget {
  final Brand brand;
  const _BrandMetrics({required this.brand});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData('أعضاء المجتمع', brand.communityMembers.toString(), Icons.groups),
      _MetricData('الحملات النشطة', brand.runningCampaigns.toString(), Icons.campaign),
      _MetricData('المكافآت النشطة', brand.activeRewards.toString(), Icons.card_giftcard),
      _MetricData('إجمالي المنتجات', brand.totalProducts.toString(), Icons.inventory),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics
              .map(
                (item) => Chip(
                  avatar: Icon(item.icon, size: 18),
                  label: Text('${item.label}: ${item.value}'),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  const _MetricData(this.label, this.value, this.icon);
}

class _LatestProductsPreview extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  const _LatestProductsPreview({required this.repository, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandProduct>>(
      stream: repository.watchProducts(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final products = snapshot.data ?? const <BrandProduct>[];
        if (products.isEmpty) {
          return const _EmptyStateCard(title: 'أحدث المنتجات', message: 'أضف منتجك الأول لبدء العرض هنا');
        }
        return _SectionCard(
          title: 'أحدث المنتجات',
          action: Text('${products.length} عنصر', style: const TextStyle(color: Colors.grey)),
          child: Column(
            children: products.take(3).map((product) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: product.imageUrl != null && product.imageUrl!.isNotEmpty ? NetworkImage(product.imageUrl!) : null,
                  child: product.imageUrl == null || product.imageUrl!.isEmpty ? const Icon(Icons.inventory_2_outlined) : null,
                ),
                title: Text(product.name),
                subtitle: Text('السعر: ${product.price.toStringAsFixed(2)} · النقاط: ${product.pointsPerUnit}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.trending_up, size: 16, color: Colors.green),
                    Text('${product.salesCount} بيع', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _LatestRewardsPreview extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  const _LatestRewardsPreview({required this.repository, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandReward>>(
      stream: repository.watchRewards(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final rewards = snapshot.data ?? const <BrandReward>[];
        if (rewards.isEmpty) {
          return const _EmptyStateCard(title: 'المكافآت الأخيرة', message: 'لا توجد مكافآت مضافة حالياً');
        }
        return _SectionCard(
          title: 'المكافآت الأخيرة',
          action: Text('${rewards.length} عنصر', style: const TextStyle(color: Colors.grey)),
          child: Column(
            children: rewards.take(3).map((reward) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.card_giftcard, color: Colors.deepPurple),
                title: Text(reward.title),
                subtitle: Text('تبدأ ${_formatDate(reward.startsAt.toDate())} · تنتهي ${_formatDate(reward.endsAt.toDate())}'),
                trailing: Chip(label: Text('${reward.points} نقطة')),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _LatestCampaignsPreview extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  const _LatestCampaignsPreview({required this.repository, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandCampaign>>(
      stream: repository.watchCampaigns(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final campaigns = snapshot.data ?? const <BrandCampaign>[];
        if (campaigns.isEmpty) {
          return const _EmptyStateCard(title: 'الحملات الأخيرة', message: 'أطلق حملتك التسويقية الأولى');
        }
        return _SectionCard(
          title: 'الحملات الأخيرة',
          action: Text('${campaigns.length} حملة', style: const TextStyle(color: Colors.grey)),
          child: Column(
            children: campaigns.take(3).map((campaign) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.campaign_outlined, color: Colors.deepOrange),
                title: Text(campaign.name),
                subtitle: Text('الحالة: ${campaign.status}'),
                trailing: Text('${campaign.budget.toStringAsFixed(0)} د.ل', style: const TextStyle(fontWeight: FontWeight.bold)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _CommunityPulseCard extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  final ValueChanged<String> onCreateCommunityAction;

  const _CommunityPulseCard({required this.repository, required this.brandId, required this.onCreateCommunityAction});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandCommunityPost>>(
      stream: repository.watchCommunityPosts(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final posts = snapshot.data ?? const <BrandCommunityPost>[];
        return _SectionCard(
          title: 'نبض المجتمع',
          action: TextButton(onPressed: () => onCreateCommunityAction('منشور'), child: const Text('منشور جديد')),
          child: posts.isEmpty
              ? const _EmptyState(message: 'لم يتم نشر أي محتوى مجتمع بعد')
              : Column(
                  children: posts.take(4).map((post) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(post.type),
                      subtitle: Text(post.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: Text(_formatDate(post.createdAt.toDate()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    );
                  }).toList(),
                ),
        );
      },
    );
  }
}

class ProductsTab extends StatefulWidget {
  final String brandId;
  final BrandContentRepository repository;
  final Future<void> Function({BrandProduct? product}) onCreateProduct;

  const ProductsTab({super.key, required this.brandId, required this.repository, required this.onCreateProduct});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _query = _searchController.text.trim()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن منتج...'),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BrandProduct>>(
            stream: widget.repository.watchProducts(widget.brandId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final products = snapshot.data ?? const <BrandProduct>[];
              final filtered = _query.isEmpty ? products : products.where((product) => product.name.contains(_query)).toList();
              if (filtered.isEmpty) {
                return const _EmptyState(message: 'لا توجد منتجات مضافة حتى الآن');
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: product.imageUrl != null && product.imageUrl!.isNotEmpty ? NetworkImage(product.imageUrl!) : null,
                        child: product.imageUrl == null || product.imageUrl!.isEmpty ? const Icon(Icons.inventory_2_outlined) : null,
                      ),
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('السعر: ${product.price.toStringAsFixed(2)} دينار'),
                          Text('النقاط: ${product.pointsPerUnit} · المبيعات: ${product.salesCount}'),
                        ],
                      ),
                      trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => widget.onCreateProduct(product: product)),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: filtered.length,
              );
            },
          ),
        ),
      ],
    );
  }
}

class RewardsTab extends StatefulWidget {
  final String brandId;
  final BrandContentRepository repository;
  final Future<void> Function({BrandReward? reward}) onCreateReward;

  const RewardsTab({super.key, required this.brandId, required this.repository, required this.onCreateReward});

  @override
  State<RewardsTab> createState() => _RewardsTabState();
}

class _RewardsTabState extends State<RewardsTab> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('الكل'), selected: _statusFilter == 'all', onSelected: (_) => setState(() => _statusFilter = 'all')),
              ChoiceChip(label: const Text('نشطة'), selected: _statusFilter == 'active', onSelected: (_) => setState(() => _statusFilter = 'active')),
              ChoiceChip(label: const Text('مستقبلية'), selected: _statusFilter == 'upcoming', onSelected: (_) => setState(() => _statusFilter = 'upcoming')),
              ChoiceChip(label: const Text('منتهية'), selected: _statusFilter == 'expired', onSelected: (_) => setState(() => _statusFilter = 'expired')),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BrandReward>>(
            stream: widget.repository.watchRewards(widget.brandId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var rewards = snapshot.data ?? const <BrandReward>[];
              if (_statusFilter != 'all') {
                rewards = rewards.where((reward) => reward.status == _statusFilter).toList();
              }
              if (rewards.isEmpty) {
                return const _EmptyState(message: 'لا توجد مكافآت ضمن هذا التصنيف');
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rewards.length,
                itemBuilder: (context, index) {
                  final reward = rewards[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.card_giftcard, color: Colors.deepPurple),
                      title: Text(reward.title),
                      subtitle: Text('من ${_formatDate(reward.startsAt.toDate())} إلى ${_formatDate(reward.endsAt.toDate())}'),
                      trailing: Chip(label: Text('${reward.points} نقطة')),
                      onTap: () => widget.onCreateReward(reward: reward),
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
}

class CampaignsTab extends StatelessWidget {
  final String brandId;
  final BrandContentRepository repository;
  const CampaignsTab({super.key, required this.brandId, required this.repository});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandCampaign>>(
      stream: repository.watchCampaigns(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final campaigns = snapshot.data ?? const <BrandCampaign>[];
        if (campaigns.isEmpty) {
          return const _EmptyState(message: 'لا توجد حملات حتى الآن');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            final campaign = campaigns[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.campaign_outlined, color: Colors.deepOrange),
                title: Text(campaign.name),
                subtitle: Text('الهدف: ${campaign.goal}'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('الحالة: ${campaign.status}'),
                    Text('${campaign.budget.toStringAsFixed(0)} د.ل'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  final Brand brand;
  final String brandId;
  final BrandContentRepository repository;

  const AnalyticsTab({super.key, required this.brand, required this.brandId, required this.repository});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: const Text('تحليل أداء المحلات'),
            subtitle: const Text('توزيع جغرافي ومقاييس تفصيلية لكل محل شريك'),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StorePerformanceAnalysisScreen(brandId: brandId),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'مؤشرات عامة',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(avatar: const Icon(Icons.inventory_2_outlined), label: Text('المنتجات: ${brand.totalProducts}')),
              Chip(avatar: const Icon(Icons.card_giftcard), label: Text('المكافآت النشطة: ${brand.activeRewards}')),
              Chip(avatar: const Icon(Icons.campaign_outlined), label: Text('الحملات الجارية: ${brand.runningCampaigns}')),
              Chip(avatar: const Icon(Icons.groups), label: Text('أعضاء المجتمع: ${brand.communityMembers}')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _AnalyticsProductsCard(repository: repository, brandId: brandId),
        const SizedBox(height: 16),
        _AnalyticsCampaignsCard(repository: repository, brandId: brandId),
      ],
    );
  }
}

class _AnalyticsProductsCard extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  const _AnalyticsProductsCard({required this.repository, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandProduct>>(
      stream: repository.watchProducts(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final products = snapshot.data ?? const <BrandProduct>[];
        final totalSales = products.fold<int>(0, (sum, item) => sum + item.salesCount);
        final avgRating = products.isEmpty ? 0 : products.fold<double>(0, (sum, item) => sum + item.averageRating) / products.length;
        return _SectionCard(
          title: 'تحليلات المنتجات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عدد المنتجات: ${products.length}'),
              Text('إجمالي المبيعات المسجلة: $totalSales'),
              Text('متوسط التقييم: ${avgRating.toStringAsFixed(2)}'),
            ],
          ),
        );
      },
    );
  }
}

class _AnalyticsCampaignsCard extends StatelessWidget {
  final BrandContentRepository repository;
  final String brandId;
  const _AnalyticsCampaignsCard({required this.repository, required this.brandId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandCampaign>>(
      stream: repository.watchCampaigns(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())));
        }
        final campaigns = snapshot.data ?? const <BrandCampaign>[];
        final totalBudget = campaigns.fold<double>(0, (sum, item) => sum + item.budget);
        return _SectionCard(
          title: 'أداء الحملات',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عدد الحملات: ${campaigns.length}'),
              Text('إجمالي الميزانيات: ${totalBudget.toStringAsFixed(0)} د.ل'),
              Text('الحملات النشطة: ${campaigns.where((campaign) => campaign.status.contains('نش')).length}'),
            ],
          ),
        );
      },
    );
  }
}

class CommunityTab extends StatelessWidget {
  final String brandId;
  final BrandContentRepository repository;
  final ValueChanged<String> onCreatePost;

  const CommunityTab({super.key, required this.brandId, required this.repository, required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<BrandCommunityPost>>(
      stream: repository.watchCommunityPosts(brandId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data ?? const <BrandCommunityPost>[];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () => onCreatePost('منشور'),
                icon: const Icon(Icons.post_add),
                label: const Text('إنشاء منشور جديد'),
              ),
            ),
            Expanded(
              child: posts.isEmpty
                  ? const _EmptyState(message: 'لا توجد منشورات مجتمع حتى الآن')
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.forum_outlined),
                            title: Text(post.type),
                            subtitle: Text(post.content),
                            trailing: Text(_formatDate(post.createdAt.toDate()), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class SettingsTab extends StatelessWidget {
  final Brand brand;
  const SettingsTab({super.key, required this.brand});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'معلومات العلامة',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(contentPadding: EdgeInsets.zero, title: const Text('البريد الإلكتروني'), subtitle: Text(brand.email)),
              if (brand.contactNumber != null && brand.contactNumber!.isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('رقم التواصل'), subtitle: Text(brand.contactNumber!)),
              if (brand.website != null && brand.website!.isNotEmpty)
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('الموقع الإلكتروني'), subtitle: Text(brand.website!)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'التفضيلات',
          child: Column(
            children: const [
              ListTile(leading: Icon(Icons.notifications_active_outlined), title: Text('إعدادات الإشعارات')),
              ListTile(leading: Icon(Icons.language), title: Text('اللغة والمنطقة')),
              ListTile(leading: Icon(Icons.security), title: Text('الصلاحيات والأمان')),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyStateCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: title, child: _EmptyState(message: message));
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined, size: 42, color: Colors.grey),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _BottomSheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(onPressed: () => Navigator.of(context).pop(false), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
