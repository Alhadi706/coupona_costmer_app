import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/company_server_service.dart';

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

Future<void> showRewardCreationDialog({
  required BuildContext context,
  required Future<void> Function(RewardCreationData data) onSave,
}) async {
  final name = TextEditingController();
  final points = TextEditingController();
  final description = TextEditingController();
  final pickup = TextEditingController();
  final quantity = TextEditingController();
  String kind = 'physical';
  bool drawEnabled = false;
  bool saving = false;
  DateTime? expiresAt;
  XFile? image;

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('إضافة جائزة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الجائزة')),
                TextField(controller: points, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد النقاط المطلوبة')),
                TextField(controller: description, decoration: const InputDecoration(labelText: 'وصف الجائزة')),
                TextField(controller: pickup, decoration: const InputDecoration(labelText: 'أين وكيف يتم الاستلام؟')),
                TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'عدد الجوائز (اختياري)')),
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'نوع الجائزة'),
                  items: const [
                    DropdownMenuItem(value: 'physical', child: Text('استلام مباشر')),
                    DropdownMenuItem(value: 'digital', child: Text('رقمية')),
                  ],
                  onChanged: saving ? null : (value) => setDialogState(() => kind = value ?? 'physical'),
                ),
                SwitchListTile(
                  title: const Text('سحب عشوائي عند انتهاء المدة'),
                  value: drawEnabled,
                  onChanged: saving ? null : (value) => setDialogState(() => drawEnabled = value),
                ),
                if (drawEnabled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'لا حاجة لأي شراء إضافي للمشاركة، السحب مبني على نقاط العميل المكتسبة من مشترياته العادية. يجب تحديد تاريخ انتهاء قبل تنفيذ السحب.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(expiresAt == null ? 'تحديد مدة الجائزة' : 'تنتهي في ${expiresAt!.toLocal().toString().split(' ').first}'),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: saving
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: dialogContext,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                            initialDate: expiresAt ?? DateTime.now().add(const Duration(days: 30)),
                          );
                          if (picked != null) setDialogState(() => expiresAt = picked);
                        },
                ),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
                          if (picked != null) setDialogState(() => image = picked);
                        },
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(image == null ? 'اختيار صورة' : 'تم اختيار الصورة'),
                ),
                OutlinedButton.icon(
                  onPressed: saving
                      ? null
                      : () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.camera);
                          if (picked != null) setDialogState(() => image = picked);
                        },
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('التقاط صورة بالكاميرا'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final cost = int.tryParse(points.text.trim());
                      if (name.text.trim().isEmpty || cost == null || cost <= 0) return;
                      if (drawEnabled && expiresAt == null) return;
                      setDialogState(() => saving = true);
                      try {
                        String? imageUrl;
                        if (image != null) {
                          imageUrl = await CompanyServerService.uploadImageBytes(await image!.readAsBytes());
                        }
                        await onSave(RewardCreationData(
                          rewardName: name.text.trim(),
                          points: cost,
                          description: description.text.trim(),
                          imageUrl: imageUrl,
                          kind: kind,
                          expiresAt: expiresAt,
                          quantityLimit: int.tryParse(quantity.text.trim()),
                          pickupInstructions: pickup.text.trim(),
                          drawEnabled: drawEnabled,
                        ));
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } finally {
                        if (dialogContext.mounted) setDialogState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('حفظ الجائزة'),
            ),
          ],
        ),
      ),
    );
  } finally {
    name.dispose();
    points.dispose();
    description.dispose();
    pickup.dispose();
    quantity.dispose();
  }
}