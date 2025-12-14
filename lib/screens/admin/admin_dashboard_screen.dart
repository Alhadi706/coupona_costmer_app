import 'package:flutter/material.dart';

import '../../models/admin_user.dart';
import '../../services/firestore/admin_user_repository.dart';

class AdminMenuItem {
  const AdminMenuItem(this.emoji, this.label, this.routeName);
  final String emoji;
  final String label;
  final String routeName;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  late final List<AdminMenuItem> _menuItems = [
    const AdminMenuItem('🏠', 'الرئيسية', '/admin/home'),
    const AdminMenuItem('👥', 'المستخدمين', '/admin/users'),
    const AdminMenuItem('🏪', 'التجار', '/admin/merchants'),
    const AdminMenuItem('🏷️', 'العلامات', '/admin/brands'),
    const AdminMenuItem('📊', 'الإحصائيات', '/admin/analytics'),
    const AdminMenuItem('📝', 'المحتوى', '/admin/content'),
    const AdminMenuItem('💰', 'المدفوعات', '/admin/payments'),
    const AdminMenuItem('🚨', 'البلاغات', '/admin/reports'),
    const AdminMenuItem('⚙️', 'الإعدادات', '/admin/settings'),
    const AdminMenuItem('🛠️', 'النظام', '/admin/system'),
  ];

  void _handleNavigation(int index) {
    setState(() => _selectedIndex = index);
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return AdminHomeScreen(onNavigate: _handleNavigation);
      case 1:
        return const UsersManagementScreen();
      case 2:
        return const MerchantsManagementScreen();
      case 3:
        return const BrandsManagementScreen();
      case 4:
        return const AnalyticsDashboardScreen();
      case 5:
        return const ContentModerationScreen();
      case 6:
        return const PaymentsManagementScreen();
      case 7:
        return const ReportsManagementScreen();
      case 8:
        return const AdminSettingsScreen();
      case 9:
        return const SystemManagementScreen();
      default:
        return AdminHomeScreen(onNavigate: _handleNavigation);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 260,
              child: AdminSidebar(
                items: _menuItems,
                selectedIndex: _selectedIndex,
                onItemSelected: _handleNavigation,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: _getSelectedScreen()),
          ],
        ),
      ),
    );
  }
}

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key, required this.items, required this.selectedIndex, required this.onItemSelected});

  final List<AdminMenuItem> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('كوبونا', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('لوحة الإدارة', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == selectedIndex;
                return ListTile(
                  leading: Text(item.emoji, style: const TextStyle(fontSize: 18)),
                  title: Text(item.label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                  selected: isSelected,
                  selectedTileColor: Colors.deepPurple.shade50,
                  onTap: () => onItemSelected(index),
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('تسجيل الخروج'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم الإدارية'),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildLiveStatsGrid(context),
            const SizedBox(height: 24),
            _buildGrowthChart(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
            const SizedBox(height: 24),
            _buildActiveIssues(),
            const SizedBox(height: 24),
            _buildCriticalAlerts(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('مرحباً في لوحة التحكم', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('يمكنك مراقبة الأداء، إدارة المستخدمين، ومعالجة البلاغات من مكان واحد.'),
                ],
              ),
            ),
            FilledButton.icon(onPressed: () => onNavigate(7), icon: const Icon(Icons.warning_amber), label: const Text('عرض البلاغات')),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatsGrid(BuildContext context) {
    final stats = [
      StatCardData('المستخدمين', '45,892', '+12.5%', Icons.people, Colors.blue, () => onNavigate(1)),
      StatCardData('التجار', '2,145', '+8.3%', Icons.store, Colors.green, () => onNavigate(2)),
      StatCardData('العلامات', '156', '+5.2%', Icons.branding_watermark, Colors.purple, () => onNavigate(3)),
      StatCardData('الإيرادات', '125,450 د.ل', '+23.1%', Icons.attach_money, Colors.amber, () => onNavigate(6)),
      StatCardData('الفواتير', '892,456', '+18.7%', Icons.receipt_long, Colors.cyan, null),
      StatCardData('التفاعلات', '2.4M', '+32.5%', Icons.trending_up, Colors.pink, null),
      StatCardData('البلاغات', '1,245', '-5.2%', Icons.warning, Colors.red, () => onNavigate(7)),
      StatCardData('المحتوى', '45,892', '+15.3%', Icons.article_outlined, Colors.teal, () => onNavigate(5)),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.6,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: stats.map((stat) => StatCard(data: stat)).toList(),
    );
  }

  Widget _buildGrowthChart() {
    return SectionCard(
      title: 'مخطط النمو',
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: const Text('سيتم رسم مخطط النمو هنا'),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final items = [
      'تمت الموافقة على 24 حساب تاجر جديد.',
      'تم إرسال 3 تحذيرات لمستخدمين بسبب نشاط مشبوه.',
      'تم إنشاء تقرير أداء أسبوعي جديد.',
      'قام النظام بجدولة نسخ احتياطي تلقائي.',
    ];
    return SectionCard(
      title: 'نشاط النظام الأخير',
      child: Column(
        children: items
            .map((activity) => ListTile(
                  leading: const Icon(Icons.timeline),
                  title: Text(activity),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildActiveIssues() {
    final issues = [
      ('API', 'ارتفاع ملحوظ في زمن الاستجابة', Colors.orange),
      ('المدفوعات', 'تأخر في تأكيد بعض التحويلات', Colors.red),
      ('التنبيهات', 'بعض المستخدمين لا يستلمون إشعارات الويب', Colors.amber),
    ];
    return SectionCard(
      title: 'المشاكل النشطة',
      child: Column(
        children: issues
            .map(
              (issue) => ListTile(
                leading: CircleAvatar(backgroundColor: issue.$3.withValues(alpha: 0.1), child: Icon(Icons.error, color: issue.$3)),
                title: Text(issue.$1),
                subtitle: Text(issue.$2),
                trailing: TextButton(onPressed: () => onNavigate(9), child: const Text('متابعة')),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCriticalAlerts() {
    final alerts = [
      ('تنبيه أمني', 'تم اكتشاف 12 محاولة تسجيل مشبوهة خلال الساعة الماضية.'),
      ('فلترة محتوى', 'يوجد 18 محتوى بانتظار مراجعة عاجلة.'),
      ('النظام المالي', 'تم تعليق دفعة مجمعة بقيمة 8,400 د.ل للتدقيق.'),
    ];
    return SectionCard(
      title: 'التنبيهات المهمة',
      child: Column(
        children: alerts
            .map((alert) => Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.priority_high, color: Colors.red),
                    title: Text(alert.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(alert.$2),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class StatCardData {
  const StatCardData(this.title, this.value, this.change, this.icon, this.color, this.onTap);
  final String title;
  final String value;
  final String change;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.data});
  final StatCardData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: data.color.withValues(alpha: 0.12),
                child: Icon(data.icon, color: data.color),
              ),
              const Spacer(),
              Text(data.title, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(data.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(data.change, style: TextStyle(color: data.change.contains('-') ? Colors.red : Colors.green)),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (trailing != null) trailing!,
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

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final AdminUserRepository _repository = AdminUserRepository();
  String _search = '';
  String _segment = 'all';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المستخدمين')),
      body: Column(
        children: [
          _buildUsersFilterBar(),
          _buildUsersStats(),
          Expanded(
            child: StreamBuilder<List<AdminUser>>(
              stream: _repository.watchUsers(
                roleFilter: _segment == 'all' ? null : _segment,
                searchTerm: _search,
                limit: 200,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final users = snapshot.data ?? const <AdminUser>[];
                if (users.isEmpty) {
                  return const Center(child: Text('لا يوجد مستخدمون مطابقون للمعايير الحالية.'));
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('المستخدم')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('الحالة')),
                      DataColumn(label: Text('النقاط')),
                      DataColumn(label: Text('آخر نشاط')),
                      DataColumn(label: Text('إجراءات')),
                    ],
                    rows: users
                        .map(
                          (user) => DataRow(
                            cells: [
                              DataCell(ListTile(
                                leading: CircleAvatar(child: Text(user.displayName.isNotEmpty ? user.displayName.characters.first : '?')),
                                title: Text(user.displayName),
                                subtitle: Text(user.email.isEmpty ? 'لا يوجد بريد' : user.email),
                              )),
                              DataCell(Chip(label: Text(user.displayRole))),
                              DataCell(Switch(
                                value: user.isActive,
                                onChanged: _isProcessing ? null : (value) => _toggleUserStatus(user, value),
                              )),
                              DataCell(Text(user.totalPoints.toStringAsFixed(0))),
                              DataCell(Text(_formatDate(user.lastActive ?? user.createdAt))),
                              DataCell(
                                _UserActionsMenu(
                                  user: user,
                                  onView: _viewUserDetails,
                                  onEdit: _editUser,
                                  onMessage: _sendMessageToUser,
                                  onWarn: _warnUser,
                                  onBan: _banUser,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                );
              },
            ),
          ),
          _buildBulkActions(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _createUser, icon: const Icon(Icons.add), label: const Text('مستخدم جديد')),
    );
  }

  Widget _buildUsersFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'ابحث عن مستخدم...'),
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: const Text('الكل'), selected: _segment == 'all', onSelected: (_) => setState(() => _segment = 'all')),
              ChoiceChip(label: const Text('زبائن'), selected: _segment == 'customer', onSelected: (_) => setState(() => _segment = 'customer')),
              ChoiceChip(label: const Text('تجار'), selected: _segment == 'merchant', onSelected: (_) => setState(() => _segment = 'merchant')),
              ChoiceChip(label: const Text('علامات'), selected: _segment == 'brand', onSelected: (_) => setState(() => _segment = 'brand')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersStats() {
    return StreamBuilder<AdminUserStats>(
      stream: _repository.watchStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const AdminUserStats(active: 0, suspended: 0, needsReview: 0);
        final tiles = [
          ('المستخدمون النشطون', stats.active),
          ('المستخدمون المعلقون', stats.suspended),
          ('مستخدمون بحاجة لمراجعة', stats.needsReview),
        ];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: tiles
                .map(
                  (stat) => Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(stat.$1, style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('${stat.$2}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildBulkActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        children: [
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.mail), label: const Text('إرسال رسالة')), 
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.warning_amber), label: const Text('تحذير جماعي')),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.block), label: const Text('حظر مؤقت')),
        ],
      ),
    );
  }

  Future<void> _toggleUserStatus(AdminUser user, bool value) async {
    setState(() => _isProcessing = true);
    try {
      await _repository.updateUserStatus(user.id, value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'تم تفعيل ${user.displayName}' : 'تم تعليق ${user.displayName}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تعديل حالة المستخدم: $error')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _viewUserDetails(AdminUser user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('تفاصيل ${user.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('البريد: ${user.email.isEmpty ? 'غير متوفر' : user.email}'),
            Text('الدور: ${user.displayRole}'),
            Text('تاريخ الإنشاء: ${_formatDate(user.createdAt)}'),
            Text('آخر نشاط: ${_formatDate(user.lastActive ?? user.createdAt)}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _editUser(AdminUser user) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تحرير ${user.displayName} قريباً')));
  }

  void _sendMessageToUser(AdminUser user) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إرسال رسالة إلى ${user.displayName}')));
  }

  void _warnUser(AdminUser user) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تحذير ${user.displayName}')));
  }

  void _banUser(AdminUser user) {
    _toggleUserStatus(user, false);
  }

  void _createUser() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إنشاء مستخدم جديد قيد التطوير')));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'غير متوفر';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _UserActionsMenu extends StatelessWidget {
  const _UserActionsMenu({required this.user, required this.onView, required this.onEdit, required this.onMessage, required this.onWarn, required this.onBan});
  final AdminUser user;
  final ValueChanged<AdminUser> onView;
  final ValueChanged<AdminUser> onEdit;
  final ValueChanged<AdminUser> onMessage;
  final ValueChanged<AdminUser> onWarn;
  final ValueChanged<AdminUser> onBan;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'view':
            onView(user);
            break;
          case 'edit':
            onEdit(user);
            break;
          case 'message':
            onMessage(user);
            break;
          case 'warn':
            onWarn(user);
            break;
          case 'ban':
            onBan(user);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.visibility), title: Text('عرض'))),
        PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('تعديل'))),
        PopupMenuItem(value: 'message', child: ListTile(leading: Icon(Icons.mail_outline), title: Text('رسالة'))),
        PopupMenuItem(value: 'warn', child: ListTile(leading: Icon(Icons.warning, color: Colors.orange), title: Text('تحذير'))),
        PopupMenuItem(value: 'ban', child: ListTile(leading: Icon(Icons.block, color: Colors.red), title: Text('حظر'))),
      ],
    );
  }
}

class MerchantsManagementScreen extends StatelessWidget {
  const MerchantsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ['بانتظار الموافقة', 'النشطين', 'المعلقين', 'المحظورين'];
    return DefaultTabController(
      length: categories.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة التجار'),
          bottom: TabBar(tabs: categories.map((tab) => Tab(text: tab)).toList()),
        ),
        body: TabBarView(
          children: categories.map((category) => _buildMerchantList(category)).toList(),
        ),
      ),
    );
  }

  Widget _buildMerchantList(String category) {
    final merchants = List.generate(
      6,
      (index) => _MerchantSummary(
        id: '$category-$index',
        name: 'تاجر $index',
        category: 'مواد غذائية',
        location: 'طرابلس',
        registrationDate: DateTime.now().subtract(Duration(days: index * 3)),
        status: category,
      ),
    );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: merchants.length,
      itemBuilder: (context, index) => _buildMerchantApprovalCard(context, merchants[index]),
    );
  }

  Widget _buildMerchantApprovalCard(BuildContext context, _MerchantSummary merchant) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(merchant.name.characters.first)),
        title: Text(merchant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(merchant.category), Text(merchant.location), Text('تاريخ التسجيل: ${merchant.formattedDate} ')]),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('وثائق التاجر', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: const [Chip(label: Text('السجل التجاري')), Chip(label: Text('إثبات الهوية')), Chip(label: Text('شهادة بنك'))]),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(onPressed: () => _showSnack(context, 'تمت الموافقة على ${merchant.name}'), icon: const Icon(Icons.check), label: const Text('موافقة')), 
                    ElevatedButton.icon(onPressed: () => _showSnack(context, 'تم طلب تعديل ${merchant.name}'), icon: const Icon(Icons.edit), label: const Text('طلب تعديل')), 
                    ElevatedButton.icon(onPressed: () => _showSnack(context, 'تم رفض ${merchant.name}'), icon: const Icon(Icons.block), label: const Text('رفض'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MerchantSummary {
  _MerchantSummary({required this.id, required this.name, required this.category, required this.location, required this.registrationDate, required this.status});
  final String id;
  final String name;
  final String category;
  final String location;
  final DateTime registrationDate;
  final String status;
  String get formattedDate => '${registrationDate.year}-${registrationDate.month.toString().padLeft(2, '0')}-${registrationDate.day.toString().padLeft(2, '0')}';
}

class BrandsManagementScreen extends StatelessWidget {
  const BrandsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brands = List.generate(
      8,
      (index) => _BrandSummary(id: 'brand_$index', name: 'علامة $index', campaigns: 4 + index, rewards: 2 + index, status: index.isEven ? 'نشطة' : 'بانتظار المراجعة'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة العلامات التجارية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: brands
            .map(
              (brand) => Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text(brand.name.characters.first)),
                  title: Text(brand.name),
                  subtitle: Text('الحملات: ${brand.campaigns} · المكافآت: ${brand.rewards}'),
                  trailing: Chip(label: Text(brand.status)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _BrandSummary {
  _BrandSummary({required this.id, required this.name, required this.campaigns, required this.rewards, required this.status});
  final String id;
  final String name;
  final int campaigns;
  final int rewards;
  final String status;
}

class ContentModerationScreen extends StatelessWidget {
  const ContentModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportedContent = List.generate(
      5,
      (index) => _ReportedContent(id: 'content_$index', user: 'مستخدم $index', reason: 'محتوى مخالف', createdAt: DateTime.now().subtract(Duration(hours: index * 4)), status: index.isEven ? 'بانتظار المراجعة' : 'تمت المعالجة'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('مراقبة المحتوى')),
      body: Column(
        children: [
          _buildQuickModerationBar(),
          Expanded(
            child: ListView.builder(
              itemCount: reportedContent.length,
              itemBuilder: (context, index) {
                final content = reportedContent[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.report_gmailerrorred, color: Colors.orange),
                    title: Text(content.user),
                    subtitle: Text('${content.reason} · ${content.formattedDate}'),
                    trailing: Chip(label: Text(content.status)),
                    onTap: () => _openReviewDialog(context, content),
                  ),
                );
              },
            ),
          ),
          _buildModerationStats(),
        ],
      ),
    );
  }

  Widget _buildQuickModerationBar() {
    final actions = ['محتوى جديد', 'بلاغات اليوم', 'قرارات مفتوحة', 'تمت الموافقة'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        children: actions.map((action) => ActionChip(label: Text(action), onPressed: () {})).toList(),
      ),
    );
  }

  Widget _buildModerationStats() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: const [
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('قيد المراجعة: 18')))),
          SizedBox(width: 12),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('تمت الموافقة: 230')))),
          SizedBox(width: 12),
          Expanded(child: Card(child: Padding(padding: EdgeInsets.all(12), child: Text('تم الحذف: 42')))),
        ],
      ),
    );
  }

  void _openReviewDialog(BuildContext context, _ReportedContent content) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 520,
          height: 420,
          child: Column(
            children: [
              AppBar(title: Text('مراجعة ${content.user}'), automaticallyImplyLeading: false, actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))]),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('السبب: ${content.reason}'), const SizedBox(height: 12), const Text('نص المحتوى سيتم عرضه هنا.')]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.check), label: const Text('موافقة')),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.warning), label: const Text('تحذير')),
                    OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.delete), label: const Text('حذف')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportedContent {
  _ReportedContent({required this.id, required this.user, required this.reason, required this.createdAt, required this.status});
  final String id;
  final String user;
  final String reason;
  final DateTime createdAt;
  final String status;
  String get formattedDate => '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';
}

class PaymentsManagementScreen extends StatelessWidget {
  const PaymentsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payments = List.generate(
      10,
      (index) => _PaymentSummary(id: 'txn_$index', entity: 'تاجر $index', amount: 1200 + index * 50, status: index % 3 == 0 ? 'معلق' : 'مكتمل', date: DateTime.now().subtract(Duration(days: index))),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المدفوعات')), 
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: payments
            .map((payment) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: Text(payment.entity),
                    subtitle: Text('${payment.amount.toStringAsFixed(2)} د.ل · ${payment.formattedDate}'),
                    trailing: Chip(label: Text(payment.status)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _PaymentSummary {
  _PaymentSummary({required this.id, required this.entity, required this.amount, required this.status, required this.date});
  final String id;
  final String entity;
  final double amount;
  final String status;
  final DateTime date;
  String get formattedDate => '${date.year}-${date.month}-${date.day}';
}

class ReportsManagementScreen extends StatelessWidget {
  const ReportsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة البلاغات')), 
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(
          6,
          (index) => Card(
            child: ListTile(
              leading: const Icon(Icons.report_problem, color: Colors.red),
              title: Text('بلاغ #$index'),
              subtitle: const Text('تفاصيل البلاغ ستظهر هنا...'),
              trailing: TextButton(onPressed: () {}, child: const Text('فتح')),
            ),
          ),
        ),
      ),
    );
  }
}

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة التحليلات')), 
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(title: 'الفلاتر', child: Wrap(spacing: 12, children: [ElevatedButton(onPressed: () {}, child: const Text('آخر 7 أيام')), ElevatedButton(onPressed: () {}, child: const Text('آخر 30 يوماً')), ElevatedButton(onPressed: () {}, child: const Text('هذا العام'))])),
          SectionCard(title: 'الإيرادات', child: _chartPlaceholder()),
          SectionCard(title: 'نمو المستخدمين', child: _chartPlaceholder()),
          SectionCard(title: 'تحليلات التفاعل', child: _chartPlaceholder()),
          SectionCard(title: 'تقارير مخصصة', child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.download), label: const Text('إنشاء تقرير جديد'))),
        ],
      ),
    );
  }

  Widget _chartPlaceholder() {
    return Container(height: 220, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Text('Placeholder للمخطط'));
  }
}

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _maintenanceMode = false;
  bool _allowRegistrations = true;
  bool _isCommunityEnabled = true;
  String _language = 'العربية';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')), 
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(title: const Text('وضع الصيانة'), subtitle: const Text('تعطيل التطبيق لإجراء الصيانة'), value: _maintenanceMode, onChanged: (value) => setState(() => _maintenanceMode = value)),
          SwitchListTile(title: const Text('السماح بتسجيل جديد'), value: _allowRegistrations, onChanged: (value) => setState(() => _allowRegistrations = value)),
          SwitchListTile(title: const Text('تفعيل المجتمع'), value: _isCommunityEnabled, onChanged: (value) => setState(() => _isCommunityEnabled = value)),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('اللغة الافتراضية'),
            trailing: DropdownButton<String>(
              value: _language,
              items: const [DropdownMenuItem(value: 'العربية', child: Text('العربية')), DropdownMenuItem(value: 'الإنجليزية', child: Text('الإنجليزية')), DropdownMenuItem(value: 'الفرنسية', child: Text('الفرنسية'))],
              onChanged: (value) => setState(() => _language = value ?? 'العربية'),
            ),
          ),
        ],
      ),
    );
  }
}

class SystemManagementScreen extends StatelessWidget {
  const SystemManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('النظام')), 
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(title: 'إعدادات النظام', child: Column(children: [SwitchListTile(title: const Text('تشغيل وضع الصيانة'), value: false, onChanged: (_) {}), SwitchListTile(title: const Text('تمكين الإشعارات'), value: true, onChanged: (_) {})])),
          SectionCard(title: 'إدارة الخدمات', child: Column(children: [ListTile(leading: const Icon(Icons.cloud), title: const Text('خدمة التخزين'), subtitle: const Text('فعالة')), ListTile(leading: const Icon(Icons.security), title: const Text('خدمة الأمان'), subtitle: const Text('فعالة'))])),
          SectionCard(title: 'النسخ الاحتياطي', child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.backup), label: const Text('تشغيل النسخ الاحتياطي'))),
          SectionCard(title: 'سجلات النظام', child: Column(children: List.generate(3, (index) => ListTile(leading: const Icon(Icons.list), title: Text('Log #$index'), subtitle: const Text('تفاصيل السجل...'))))),
        ],
      ),
    );
  }
}
