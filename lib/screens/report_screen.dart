import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({Key? key}) : super(key: key);

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedType;
  String? _storeName;
  String? _description;
  XFile? _pickedImage;

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  void _submitReport() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('report_sent'.tr()),
          content: Text('report_sent_message'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
      // هنا يمكن إضافة منطق إرسال البلاغ للسيرفر لاحقًا
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> _reportTypes = [
      'expired',
      'bad_service',
      'inappropriate_treatment',
      'price_not_matching_offer',
      'misleading_advertisement',
      'other_report',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('report_product_or_service'.tr()),
        backgroundColor: Colors.deepPurple.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'report_type'.tr(),
                  border: OutlineInputBorder(),
                ),
                value: _selectedType,
                items: _reportTypes.map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type.tr()),
                )).toList(),
                onChanged: (val) => setState(() => _selectedType = val),
                validator: (val) => val == null ? 'please_select_report_type'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'store_name_or_entity'.tr(),
                  hintText: 'example_supermarket_rabea'.tr(),
                  border: OutlineInputBorder(),
                ),
                onSaved: (val) => _storeName = val,
                validator: (val) => (val == null || val.isEmpty) ? 'please_enter_store_name'.tr() : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'report_description'.tr(),
                  hintText: 'write_details_here'.tr(),
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                onSaved: (val) => _description = val,
                validator: (val) => (val == null || val.isEmpty) ? 'please_write_report_description'.tr() : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.attach_file),
                    label: Text('attach_image_or_invoice'.tr()),
                  ),
                  const SizedBox(width: 12),
                  if (_pickedImage != null)
                    Expanded(
                      child: Text(
                        'image_selected_report'.tr(),
                        style: TextStyle(color: Colors.green.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitReport,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white, // لون النص
                    textStyle: TextStyle(fontWeight: FontWeight.bold),
                    backgroundColor: Colors.deepPurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text('send_report'.tr(), style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

