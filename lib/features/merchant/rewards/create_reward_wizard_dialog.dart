import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:coupona_app/services/company_server_service.dart';

class CreateRewardWizardDialog extends StatefulWidget {
  final Future<void> Function(RewardCreationData data) onSave;

  const CreateRewardWizardDialog({super.key, required this.onSave});

  @override
  State<CreateRewardWizardDialog> createState() => _CreateRewardWizardDialogState();
}

class _CreateRewardWizardDialogState extends State<CreateRewardWizardDialog> {
  int _currentStep = 0;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _pointsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  
  String _rewardType = 'منتج مجاني';
  String _tierTarget = 'all';
  DateTime? _expiresAt;
  XFile? _image;
  bool _saving = false;

  final List<String> _rewardTypes = [
    'منتج مجاني',
    'قسيمة خصم',
    'مبلغ مالي / كاش باك',
  ];

  final List<Map<String, String>> _tierOptions = [
    {'value': 'all', 'label': 'الكل (جميع المستويات)'},
    {'value': 'silver_gold', 'label': 'الفضي والذهبي فقط'},
    {'value': 'gold_only', 'label': 'الذهبي فقط'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _pointsController.dispose();
    _descriptionController.dispose();
    _pickupController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  List<Step> get _steps => [
    Step(
      title: const Text('تفاصيل الجائزة'),
      content: _buildStep1(),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    ),
    Step(
      title: const Text('التنفيذ والصورة'),
      content: _buildStep2(),
      isActive: _currentStep >= 1,
      state: _currentStep > 1 ? StepState.complete : StepState.indexed,
    ),
  ];

  Widget _buildStep1() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'اسم الجائزة *'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _rewardType,
            decoration: const InputDecoration(labelText: 'نوع الجائزة'),
            items: _rewardTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: _saving ? null : (value) {
              setState(() => _rewardType = value ?? 'منتج مجاني');
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _tierTarget,
            decoration: const InputDecoration(labelText: 'المستويات المستهدفة'),
            items: _tierOptions.map((option) {
              return DropdownMenuItem(
                value: option['value'],
                child: Text(option['label']!),
              );
            }).toList(),
            onChanged: _saving ? null : (value) {
              setState(() => _tierTarget = value ?? 'all');
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pointsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد النقاط المطلوبة *'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'وصف الجائزة (اختياري)'),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(_expiresAt == null ? 'اختيار تاريخ الانتهاء (اختياري)' : 'تاريخ الانتهاء: ${_expiresAt!.toLocal()}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _saving ? null : () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
                initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) setState(() => _expiresAt = picked);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pickupController,
            decoration: const InputDecoration(labelText: 'أين وكيف يتم الاستلام؟'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'عدد الجوائز (اختياري)'),
          ),
          const SizedBox(height: 24),
          Text('اختيار صورة الجائزة', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                    if (picked != null) setState(() => _image = picked);
                  },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_image == null ? 'اختيار صورة' : 'تم اختيار الصورة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () async {
                    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                    if (picked != null) setState(() => _image = picked);
                  },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text('capture_camera_image'.tr() == 'capture_camera_image'
                      ? 'التقاط صورة'
                      : 'capture_camera_image'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  bool _validateStep1() {
    return _nameController.text.trim().isNotEmpty &&
           _pointsController.text.trim().isNotEmpty &&
           int.tryParse(_pointsController.text.trim()) != null;
  }

  Future<void> _saveReward() async {
    final cost = int.tryParse(_pointsController.text.trim());
    if (_nameController.text.trim().isEmpty || cost == null || cost <= 0) return;

    setState(() => _saving = true);
    try {
      String? imageUrl;
      if (_image != null) {
        imageUrl = await CompanyServerService.uploadImageBytes(await _image!.readAsBytes());
      }

      final data = RewardCreationData(
        rewardName: _nameController.text.trim(),
        points: cost,
        description: _descriptionController.text.trim(),
        imageUrl: imageUrl,
        kind: 'physical', // Default for now
        expiresAt: _expiresAt,
        quantityLimit: int.tryParse(_quantityController.text.trim()),
        pickupInstructions: _pickupController.text.trim(),
        drawEnabled: false, // Not implemented in wizard yet
      );

      await widget.onSave(data);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إنشاء جائزة جديدة'),
      content: SizedBox(
        width: double.maxFinite,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: () {
            if (_currentStep == 0 && !_validateStep1()) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('يرجى تعبئة الحقول المطلوبة')),
              );
              return;
            }
            if (_currentStep < _steps.length - 1) {
              setState(() => _currentStep += 1);
            } else {
              _saveReward();
            }
          },
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1);
            } else {
              Navigator.pop(context);
            }
          },
          steps: _steps,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  if (details.currentStep > 0)
                    OutlinedButton(
                      onPressed: _saving ? null : details.onStepCancel,
                      child: Text('cancel'.tr()),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : details.onStepContinue,
                      child: _saving
                          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(details.currentStep == _steps.length - 1 ? 'حفظ الجائزة' : 'التالي'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class RewardCreationData {
  final String rewardName;
  final int points;
  final String description;
  final String? imageUrl;
  final String kind;
  final DateTime? expiresAt;
  final int? quantityLimit;
  final String pickupInstructions;
  final bool drawEnabled;

  const RewardCreationData({
    required this.rewardName,
    required this.points,
    required this.description,
    required this.imageUrl,
    required this.kind,
    required this.expiresAt,
    required this.quantityLimit,
    required this.pickupInstructions,
    required this.drawEnabled,
  });
}