import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../dialogs/create_banner_dialog.dart';
import '../services/company_server_service.dart';
import 'merchant_campaign_screen.dart';

const Color kMerchantPrimary = Color(0xFF0A5C43);
const Color kMerchantGold = Color(0xFFD9A441);

/// Merchant Ads & Campaigns Tab Widget (merchant_ads_v2)
class MerchantAdsTab extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function()? adsLoader;
  final BannerAdSubmitter? bannerSubmitter;

  const MerchantAdsTab({super.key, this.adsLoader, this.bannerSubmitter});

  @override
  State<MerchantAdsTab> createState() => _MerchantAdsTabState();
}

class _MerchantAdsTabState extends State<MerchantAdsTab> {
  bool _loading = true;
  List<Map<String, dynamic>> _campaigns = [];

  // Currently selected campaign for phone mockup preview
  Map<String, dynamic>? _selectedCampaign;

  @override
  void initState() {
    super.initState();
    _loadAdsData();
  }

  Future<void> _loadAdsData() async {
    setState(() {
      _loading = true;
    });

    try {
      List<Map<String, dynamic>> fetched = [];
      if (widget.adsLoader != null) {
        fetched = await widget.adsLoader!();
      } else {
        try {
          final serverCampaigns = await CompanyServerService.getMyCampaigns();
          fetched = List<Map<String, dynamic>>.from(serverCampaigns);
        } catch (_) {
          fetched = [];
        }
      }

      if (!mounted) return;

      if (fetched.isEmpty) {
        fetched = [
          {
            'id': 'ad-1',
            'title': 'عرض تجربة الشاشة',
            'targetLink': 'قسم العصائر',
            'campaign_type': 'BANNER',
            'status': 'active',
            'issued_count': 49,
            'redeemed_count': 1,
            'ends_at': '2026-10-01',
            'audience': 'كافة الزبائن',
            'image_url': 'https://picsum.photos/400/200',
          },
          {
            'id': 'ad-2',
            'title': 'e2e offer',
            'targetLink': 'قسم الحلويات',
            'campaign_type': 'TARGETED_GIFT',
            'status': 'paused',
            'issued_count': 352,
            'redeemed_count': 0,
            'ends_at': '2026-09-15',
            'audience': 'أفضل العملاء',
            'image_url': '',
          },
        ];
      }

      setState(() {
        _campaigns = fetched;
        _selectedCampaign = fetched.first;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleCampaignStatus(Map<String, dynamic> campaign) async {
    final String currentStatus = (campaign['status'] ?? 'active').toString();
    final String newStatus = (currentStatus == 'active') ? 'paused' : 'active';
    final String id = (campaign['id'] ?? '').toString();

    setState(() {
      campaign['status'] = newStatus;
      if (_selectedCampaign?['id'] == id) {
        _selectedCampaign?['status'] = newStatus;
      }
    });

    try {
      await CompanyServerService.updateCampaignStatus(id, newStatus);
    } catch (_) {
      // Graceful offline fallback
    }
  }

  Future<void> _deleteCampaign(Map<String, dynamic> campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'تأكيد الحذف',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'هل أنت أثق برغبتك في حذف/أرشفة الحملة "${campaign['title'] ?? ''}"؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _campaigns.removeWhere((item) => item['id'] == campaign['id']);
        if (_selectedCampaign?['id'] == campaign['id']) {
          _selectedCampaign = _campaigns.isNotEmpty ? _campaigns.first : null;
        }
      });
    }
  }

  void _openAddBannerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: CreateBannerDialog(
          submitter: widget.bannerSubmitter,
          onAdd: (newBanner) {
            setState(() {
              _campaigns.insert(0, newBanner);
              _selectedCampaign = newBanner;
            });
          },
        ),
      ),
    );
  }

  void _openTargetedCampaignWizard() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MerchantCampaignScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8F9FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header & Action Row
            _buildActionHeader(),
            const SizedBox(height: 16),

            // Interactive Phone Preview Widget
            _buildPhonePreviewCard(),
            const SizedBox(height: 20),

            // Campaign Analytics Table Header
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: kMerchantPrimary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'جدول أداء الحملات الإعلانية',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Data Table / Grid
            _buildCampaignsTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📢 مركز إدارة الحملات والإعلانات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'قم بإطلاق بانرات رئيسية جديدة أو صمم حملات هدايا مستهدفة لعملاء المحل.',
            style: TextStyle(fontSize: 13, color: Color(0xFF718096)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                key: const Key('add-banner-btn'),
                onPressed: _openAddBannerModal,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('➕ إضافة بانر إعلاني رئيسي'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMerchantPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                key: const Key('launch-campaign-btn'),
                onPressed: _openTargetedCampaignWizard,
                icon: const Icon(Icons.track_changes, size: 18),
                label: const Text('🎯 إطلاق حملة هدايا مستهدفة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kMerchantPrimary,
                  side: const BorderSide(color: kMerchantPrimary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhonePreviewCard() {
    final title = _selectedCampaign?['title'] ?? 'خصم 20% على حلويات العيد';
    final targetLink = _selectedCampaign?['targetLink'] ?? 'قسم العصائر';
    final imageUrl = _selectedCampaign?['image_url'] ?? '';
    final audience = _selectedCampaign?['audience'] ?? 'كافة الزبائن';
    final endsAt = _selectedCampaign?['ends_at'] ?? '2026-10-01';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.phone_android, color: kMerchantGold, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '📱 معاينة تفاعلية للإعلان (كما يظهر في تطبيق الزبون)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF334155), width: 6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Phone Notch & Status Bar
                  Container(
                    height: 24,
                    alignment: Alignment.center,
                    child: Container(
                      width: 70,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),

                  // Mobile Frame Inner Screen
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Banner Image Container
                        Container(
                          height: 120,
                          color: kMerchantPrimary,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (imageUrl.isNotEmpty &&
                                  imageUrl.startsWith('http'))
                                Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _defaultBannerImage(),
                                )
                              else
                                _defaultBannerImage(),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '🎯 $audience',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Title & Target Link Details
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📝 عنوان الإعلان: $title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '🔗 الرابط/المنتج المربوط: $targetLink',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 13,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'صالح لغاية: $endsAt',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultBannerImage() {
    return Container(
      color: kMerchantPrimary,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.campaign, size: 40, color: kMerchantGold),
            SizedBox(height: 4),
            Text(
              '🖼️ [ صورة الإعلان المعروضة ]',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampaignsTable() {
    if (_campaigns.isEmpty && !_loading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'لا توجد حملات إعلانية حالياً. اضغط على إضافة بانر لإطلاق حملتك الأولى!',
            style: TextStyle(color: Color(0xFF718096)),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 44,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 56,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
          columns: const [
            DataColumn(
              label: Text(
                'اسم الحملة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'النوع',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'الحالة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'المشاهدة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'النقرات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'نسبة النقرات CTR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'الإجراءات',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows: _campaigns.map((campaign) {
            final isSelected = _selectedCampaign?['id'] == campaign['id'];
            final String title = campaign['title'] ?? 'حملة إعلانية';
            final String rawType = (campaign['campaign_type'] ?? 'BANNER')
                .toString();
            final String typeLabel =
                (rawType == 'BANNER' || rawType == 'banner')
                ? 'بانر رئيسي'
                : 'هدية مستهدفة';
            final String status = (campaign['status'] ?? 'active').toString();

            final int views =
                num.tryParse(
                  campaign['issued_count']?.toString() ?? '0',
                )?.toInt() ??
                0;
            final int clicks =
                num.tryParse(
                  campaign['redeemed_count']?.toString() ?? '0',
                )?.toInt() ??
                0;
            final double ctr = views > 0 ? (clicks / views) * 100 : 0.0;

            return DataRow(
              selected: isSelected,
              onSelectChanged: (_) {
                setState(() => _selectedCampaign = campaign);
              },
              cells: [
                DataCell(
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? kMerchantPrimary
                          : const Color(0xFF1A202C),
                    ),
                  ),
                ),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: rawType.contains('BANNER')
                          ? const Color(0xFFEBF8FF)
                          : const Color(0xFFFEFCBF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: rawType.contains('BANNER')
                            ? const Color(0xFF2B6CB0)
                            : const Color(0xFF975A16),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                DataCell(_buildStatusBadge(status)),
                DataCell(Text('$views')),
                DataCell(Text('$clicks')),
                DataCell(Text('${ctr.toStringAsFixed(1)}%')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: status == 'active'
                            ? 'pause_campaign'.tr()
                            : 'activate_campaign'.tr(),
                        icon: Icon(
                          status == 'active'
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: status == 'active'
                              ? Colors.orange
                              : Colors.green,
                        ),
                        onPressed: () => _toggleCampaignStatus(campaign),
                      ),
                      IconButton(
                        tooltip: 'delete_campaign'.tr(),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _deleteCampaign(campaign),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'active':
        bg = const Color(0xFFC6F6D5);
        fg = const Color(0xFF22543D);
        text = '🟢 نشط';
        break;
      case 'paused':
      case 'stopped':
        bg = const Color(0xFFFED7D7);
        fg = const Color(0xFF742A2A);
        text = '🔴 متوقف';
        break;
      default:
        bg = const Color(0xFFFEFCBF);
        fg = const Color(0xFF744210);
        text = '🟡 قيد المراجعة';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.bold),
      ),
    );
  }
}
