import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf_color;

import '../services/company_server_service.dart';
import '../services/export_download.dart';
import '../theme/design_tokens.dart';
import '../widgets/design_system/kupuna_status_pill.dart';

class MerchantSettingsScreen extends StatefulWidget {
  final bool embedded;

  const MerchantSettingsScreen({
    super.key,
    this.embedded = false,
  });

  const MerchantSettingsScreen.embedded({
    super.key,
  }) : embedded = true;

  @override
  State<MerchantSettingsScreen> createState() => _MerchantSettingsScreenState();
}

class _MerchantSettingsScreenState extends State<MerchantSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  bool _savingProfile = false;
  bool _bindingCashier = false;
  bool _generatingPdf = false;
  String? _errorMessage;
  String? _successMessage;

  // Profile Form Controllers
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  final TextEditingController _crController = TextEditingController();

  // Data
  Map<String, dynamic> _merchantProfile = <String, dynamic>{};
  List<Map<String, dynamic>> _branches = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _cashiers = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unassignedCashiers = <Map<String, dynamic>>[];

  // Cashier Binding Form State
  String? _selectedBranchId;
  String? _selectedCashierUserId;

  // QR Asset Selection State
  String? _selectedQrBranchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _businessNameController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _logoUrlController.dispose();
    _crController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        CompanyServerService.getMerchantProfile().catchError((_) => <String, dynamic>{}),
        CompanyServerService.getMerchantBranches().catchError((_) => <Map<String, dynamic>>[]),
        CompanyServerService.getMerchantCashiers().catchError((_) => <Map<String, dynamic>>[]),
        CompanyServerService.getUnassignedCashiers().catchError((_) => <Map<String, dynamic>>[]),
      ]);

      if (!mounted) return;

      final profile = Map<String, dynamic>.from(results[0] as Map);
      final branchesList = List<Map<String, dynamic>>.from(results[1] as List);
      final cashiersList = List<Map<String, dynamic>>.from(results[2] as List);
      final unassignedList = List<Map<String, dynamic>>.from(results[3] as List);

      _merchantProfile = profile;
      _businessNameController.text = (profile['businessName'] ?? '').toString();
      _categoryController.text = (profile['category'] ?? '').toString();
      _phoneController.text = (profile['phone'] ?? '').toString();
      _logoUrlController.text = (profile['logoUrl'] ?? '').toString();
      _crController.text = (profile['commercialRegistration'] ?? '').toString();

      _branches = branchesList;
      _cashiers = cashiersList;
      _unassignedCashiers = unassignedList;

      if (_branches.isNotEmpty) {
        _selectedBranchId ??= _branches.first['id']?.toString();
        _selectedQrBranchId ??= _branches.first['id']?.toString();
      }

      if (_unassignedCashiers.isNotEmpty) {
        _selectedCashierUserId ??= _unassignedCashiers.first['userId']?.toString() ??
            _unassignedCashiers.first['id']?.toString();
      }
    } catch (e) {
      if (mounted) {
        _errorMessage = e.toString();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _savingProfile = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final res = await CompanyServerService.updateMerchantProfile(
        businessName: _businessNameController.text.trim(),
        category: _categoryController.text.trim(),
        phone: _phoneController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        commercialRegistration: _crController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        if (res['profile'] != null) {
          _merchantProfile = Map<String, dynamic>.from(res['profile'] as Map);
        }
        _successMessage = 'merchant_profile_updated_success'.tr();
        if (_successMessage == 'merchant_profile_updated_success') {
          _successMessage = 'تم حفظ بيانات المتجر بنجاح';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage!),
          backgroundColor: kTeal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل حفظ البيانات: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  Future<void> _bindCashier() async {
    if (_selectedBranchId == null || _selectedBranchId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الفرع أولاً')),
      );
      return;
    }

    if (_selectedCashierUserId == null || _selectedCashierUserId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الكاشير المراد ربطه')),
      );
      return;
    }

    setState(() {
      _bindingCashier = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await CompanyServerService.assignCashierToBranch(
        branchId: _selectedBranchId!,
        cashierUserId: _selectedCashierUserId!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ربط الكاشير بالفرع بنجاح'),
          backgroundColor: kTeal,
        ),
      );

      // Reload cashiers & unassigned lists
      _selectedCashierUserId = null;
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل ربط الكاشير: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _bindingCashier = false;
        });
      }
    }
  }

  Future<void> _downloadQrPdf() async {
    setState(() {
      _generatingPdf = true;
    });

    try {
      final merchantId = (_merchantProfile['id'] ?? '').toString();
      final businessName = (_merchantProfile['businessName'] ?? 'متجري').toString();
      
      Map<String, dynamic>? branch;
      if (_selectedQrBranchId != null && _selectedQrBranchId!.isNotEmpty) {
        branch = _branches.firstWhere(
          (b) => (b['id'] ?? '').toString() == _selectedQrBranchId,
          orElse: () => _branches.isNotEmpty ? _branches.first : <String, dynamic>{},
        );
      } else if (_branches.isNotEmpty) {
        branch = _branches.first;
      }

      final branchName = (branch?['name'] ?? 'جميع الفروع').toString();
      final branchId = (branch?['id'] ?? '').toString();
      final qrData = 'kupuna://store/$merchantId${branchId.isEmpty ? '' : '?branch=$branchId'}';

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: pdf_color.PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(32),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: pdf_color.PdfColors.teal, width: 3),
                  borderRadius: pw.BorderRadius.circular(16),
                ),
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      businessName,
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: pdf_color.PdfColors.teal800,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'فرع: $branchName',
                      style: pw.TextStyle(
                        fontSize: 18,
                        color: pdf_color.PdfColors.grey800,
                      ),
                    ),
                    pw.SizedBox(height: 24),
                    pw.BarcodeWidget(
                      data: qrData,
                      barcode: pw.Barcode.qrCode(),
                      width: 220,
                      height: 220,
                    ),
                    pw.SizedBox(height: 24),
                    pw.Text(
                      'امسح الكود عبر تطبيق كوبونا لكسب النقاط واستخدام الكوبونات',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 14,
                        color: pdf_color.PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 16),
                    pw.Text(
                      'Kupuna POS Print Asset',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: pdf_color.PdfColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final fileName = 'kupuna-pos-qr-${businessName.replaceAll(' ', '_')}.pdf';

      await downloadBytes(
        bytes: pdfBytes,
        fileName: fileName,
        mimeType: 'application/pdf',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحميل ملف PDF بنجاح: $fileName'),
          backgroundColor: kTeal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء إنشاء ملف PDF: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _generatingPdf = false;
        });
      }
    }
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final businessName = (_merchantProfile['businessName'] ?? 'إعدادات المتجر').toString();
    final category = (_merchantProfile['category'] ?? 'نشاط تجاري').toString();
    final logoUrl = (_merchantProfile['logoUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: kTeal.withOpacity(0.1),
            backgroundImage: logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
            child: logoUrl.isEmpty
                ? const Icon(Icons.storefront, size: 32, color: Colors.teal)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  category.isEmpty ? 'الفروع، الكاشير، وبينات المتجر' : category,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, color: kTeal),
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
    );
  }

  Widget _buildStoreProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, color: kTeal, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'بيانات المتجر الأساسية',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Store Name
                TextFormField(
                  controller: _businessNameController,
                  decoration: InputDecoration(
                    labelText: 'اسم المتجر / النشاط',
                    hintText: 'أدخل اسم المتجر التجاري',
                    prefixIcon: const Icon(Icons.business, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Category
                TextFormField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: 'نوع النشاط',
                    hintText: 'مثال: غذائية، مطاعم، ملابس...',
                    prefixIcon: const Icon(Icons.category_outlined, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم التواصل',
                    hintText: '05xxxxxxxx',
                    prefixIcon: const Icon(Icons.phone_outlined, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Commercial Registration
                TextFormField(
                  controller: _crController,
                  decoration: InputDecoration(
                    labelText: 'رقم السجل التجاري',
                    hintText: '1010xxxxxx',
                    prefixIcon: const Icon(Icons.badge_outlined, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                // Logo URL
                TextFormField(
                  controller: _logoUrlController,
                  decoration: InputDecoration(
                    labelText: 'رابط اللوجو (الشعار)',
                    hintText: 'https://example.com/logo.png',
                    prefixIcon: const Icon(Icons.image_outlined, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _savingProfile ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: _savingProfile
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _savingProfile ? 'جاري الحفظ...' : 'حفظ التغييرات',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchesAndCashiersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Cashier Binding Form Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_outlined, color: kTeal, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'ربط كاشير بفرع',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر الفرع والكاشير المتاح لتأكيد عملية الربط مباشرة.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Dropdown 1: Branch Selector
                Text(
                  'اختر الفرع',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _branches.any((b) => (b['id'] ?? '').toString() == _selectedBranchId)
                      ? _selectedBranchId
                      : null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.store_outlined, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    hintText: 'اختر الفرع من القائمة',
                  ),
                  items: _branches.map((branch) {
                    final bId = (branch['id'] ?? '').toString();
                    final bName = (branch['name'] ?? 'فرع غير مسمى').toString();
                    final bAddress = (branch['address'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: bId,
                      child: Text(
                        bAddress.isNotEmpty ? '$bName ($bAddress)' : bName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedBranchId = val;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Dropdown 2: Unassigned Cashier Selector
                Text(
                  'اختر الكاشير (غير المربوط)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _unassignedCashiers.any((c) => (c['userId'] ?? c['id'] ?? '').toString() == _selectedCashierUserId)
                      ? _selectedCashierUserId
                      : null,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person_outline, color: kTeal),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    hintText: _unassignedCashiers.isEmpty
                        ? 'لا يوجد كاشير غير مربوط حالياً'
                        : 'اختر الكاشير من القائمة',
                  ),
                  items: _unassignedCashiers.map((cashier) {
                    final cId = (cashier['userId'] ?? cashier['id'] ?? '').toString();
                    final cName = (cashier['name'] ?? cashier['cashierName'] ?? 'كاشير').toString();
                    final cPhone = (cashier['phone'] ?? cashier['cashierPhone'] ?? '').toString();
                    return DropdownMenuItem<String>(
                      value: cId,
                      child: Text(
                        cPhone.isNotEmpty ? '$cName - $cPhone' : cName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCashierUserId = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Action Button: Confirm Link
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _bindingCashier ? null : _bindCashier,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: _bindingCashier
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _bindingCashier ? 'جاري التأكيد...' : 'تأكيد الربط',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Branches & Cashiers Table Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_outlined, color: kTeal, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'قائمة الفروع والكاشير المربوطين',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_branches.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'لا توجد فروع مسجلة حتى الآن.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _branches.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final branch = _branches[index];
                      final bId = (branch['id'] ?? '').toString();
                      final bName = (branch['name'] ?? 'فرع غير مسمى').toString();
                      final bAddress = (branch['address'] ?? 'بدون عنوان').toString();

                      // Find cashiers linked to this branch
                      final branchCashiers = _cashiers.where((c) => (c['branchId'] ?? '').toString() == bId).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: kTeal.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.store, color: kTeal, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: kInk,
                                      ),
                                    ),
                                    Text(
                                      bAddress,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              KupunaStatusPill(
                                labelOverride: branchCashiers.isNotEmpty ? 'نشط ومربوط' : 'غير مربوط',
                                kind: branchCashiers.isNotEmpty
                                    ? StatusPillKind.approvedMint
                                    : StatusPillKind.pending,
                              ),
                            ],
                          ),
                          if (branchCashiers.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.only(right: 44),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: branchCashiers.map((c) {
                                  final name = (c['cashierName'] ?? 'كاشير').toString();
                                  final phone = (c['cashierPhone'] ?? '').toString();
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.badge_outlined, size: 16, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (phone.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '($phone)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosAssetsTab() {
    final merchantId = (_merchantProfile['id'] ?? '').toString();
    final businessName = (_merchantProfile['businessName'] ?? 'تجربة تاجر').toString();

    Map<String, dynamic>? selectedBranch;
    if (_selectedQrBranchId != null && _selectedQrBranchId!.isNotEmpty) {
      selectedBranch = _branches.firstWhere(
        (b) => (b['id'] ?? '').toString() == _selectedQrBranchId,
        orElse: () => _branches.isNotEmpty ? _branches.first : <String, dynamic>{},
      );
    } else if (_branches.isNotEmpty) {
      selectedBranch = _branches.first;
    }

    final branchId = (selectedBranch?['id'] ?? '').toString();
    final branchName = (selectedBranch?['name'] ?? 'جميع الفروع').toString();

    final qrData = 'kupuna://store/$merchantId${branchId.isEmpty ? '' : '?branch=$branchId'}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_outlined, color: kTeal, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      'كود QR الخاص بالمتجر',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'اطبع الكود واعرضه في الفرع للتعريف بالمتجر والفرع.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 20),

                // Branch selector for QR code if branches exist
                if (_branches.isNotEmpty) ...[
                  SizedBox(
                    width: 300,
                    child: DropdownButtonFormField<String>(
                      value: _branches.any((b) => (b['id'] ?? '').toString() == _selectedQrBranchId)
                          ? _selectedQrBranchId
                          : _branches.first['id']?.toString(),
                      decoration: InputDecoration(
                        labelText: 'اختر الفرع لعرض الكود',
                        prefixIcon: const Icon(Icons.storefront_outlined, color: kTeal),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: _branches.map((b) {
                        return DropdownMenuItem<String>(
                          value: (b['id'] ?? '').toString(),
                          child: Text((b['name'] ?? 'فرع').toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedQrBranchId = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // QR Container Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (merchantId.isNotEmpty)
                        QrImageView(
                          data: qrData,
                          size: 200,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        )
                      else
                        const SizedBox(
                          height: 200,
                          width: 200,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: kTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$businessName - $branchName',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kTeal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Download PDF Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _generatingPdf ? null : _downloadQrPdf,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kInk,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                    ),
                    icon: _generatingPdf
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      _generatingPdf ? 'جاري إنشاء PDF...' : 'تحميل PDF للطباعة',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: kTeal),
        ),
      );
    }

    return Column(
      children: [
        _buildHeaderCard(),
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                  onPressed: () => setState(() => _errorMessage = null),
                ),
              ],
            ),
          ),

        // Tabs Header
        Container(
          decoration: _cardDecoration(),
          child: TabBar(
            controller: _tabController,
            labelColor: kTeal,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: kTeal,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(
                icon: Icon(Icons.storefront_outlined, size: 20),
                text: 'بيانات المتجر',
              ),
              Tab(
                icon: Icon(Icons.store_outlined, size: 20),
                text: 'الفروع والكاشير',
              ),
              Tab(
                icon: Icon(Icons.qr_code_2_outlined, size: 20),
                text: 'POS & QR',
              ),
            ],
          ),
        ),

        // Tabs Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStoreProfileTab(),
              _buildBranchesAndCashiersTab(),
              _buildPosAssetsTab(),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'إعدادات المتجر',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: kInk),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }
}
