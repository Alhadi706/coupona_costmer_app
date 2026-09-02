import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/company_server_service.dart';

typedef BrandProductCreator = Future<Map<String, dynamic>> Function({required String name, String? imageUrl, String? barcode});
typedef BrandProductUpdater = Future<Map<String, dynamic>> Function({required String productId, required String name, String? imageUrl, String? barcode});
typedef BrandProductDeactivator = Future<Map<String, dynamic>> Function(String productId);
typedef BrandProductImageSelector = Future<String?> Function();
typedef BrandProductBarcodeSelector = Future<String?> Function();

class BrandProductCatalog extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final BrandProductCreator createProduct;
  final BrandProductUpdater updateProduct;
  final BrandProductDeactivator deactivateProduct;
  final Future<void> Function() reload;
  final BrandProductImageSelector? imageSelector;
  final BrandProductBarcodeSelector? barcodeSelector;

  const BrandProductCatalog({
    super.key,
    required this.products,
    required this.createProduct,
    required this.updateProduct,
    required this.deactivateProduct,
    required this.reload,
    this.imageSelector,
    this.barcodeSelector,
  });

  @override
  State<BrandProductCatalog> createState() => _BrandProductCatalogState();
}

class _BrandProductCatalogState extends State<BrandProductCatalog> {
  String _search = '';
  String _status = 'all';

  @override
  Widget build(BuildContext context) {
    final normalizedSearch = _search.trim().toLowerCase();
    final visibleProducts = widget.products.where((product) {
      final isActive = product['isActive'] != false;
      final matchesStatus = _status == 'all' || (_status == 'active' && isActive) || (_status == 'inactive' && !isActive);
      final searchable = '${product['name'] ?? ''} ${product['barcode'] ?? ''}'.toLowerCase();
      return matchesStatus && (normalizedSearch.isEmpty || searchable.contains(normalizedSearch));
    }).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('brand-product-search'),
          decoration: InputDecoration(labelText: 'brand_product_search'.tr(), prefixIcon: const Icon(Icons.search)),
          onChanged: (value) => setState(() => _search = value),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<String>(
            key: const Key('brand-product-status-filter'),
            segments: [
              ButtonSegment(value: 'all', label: Text('brand_product_filter_all'.tr())),
              ButtonSegment(value: 'active', label: Text('brand_product_active'.tr())),
              ButtonSegment(value: 'inactive', label: Text('brand_product_inactive'.tr())),
            ],
            selected: {_status},
            onSelectionChanged: (selection) => setState(() => _status = selection.first),
          ),
        ),
        const SizedBox(height: 8),
        ...visibleProducts.map(_buildProductTile),
        if (visibleProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(widget.products.isEmpty ? 'brand_products_empty'.tr() : 'brand_products_filter_empty'.tr()),
          ),
        OutlinedButton.icon(
          onPressed: _showProductDialog,
          icon: const Icon(Icons.add_box_outlined),
          label: Text('brand_add_product'.tr()),
        ),
      ],
    );
  }

  Widget _buildProductTile(Map<String, dynamic> product) {
    final isActive = product['isActive'] != false;
    final imageUrl = (product['imageUrl'] ?? '').toString();
    return Card(
      child: ListTile(
        leading: imageUrl.isEmpty
            ? Icon(Icons.inventory_2_outlined, color: isActive ? const Color(0xFF6C63FF) : Colors.grey)
            : ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.square(dimension: 48, child: Icon(Icons.broken_image_outlined)),
                ),
              ),
        title: Text((product['name'] ?? '-').toString()),
        subtitle: Text('${'brand_product_barcode'.tr()}: ${(product['barcode'] ?? '-').toString()} • ${isActive ? 'brand_product_active'.tr() : 'brand_product_inactive'.tr()}'),
        enabled: isActive,
        trailing: PopupMenuButton<String>(
          key: Key('brand-product-menu-${product['id']}'),
          tooltip: 'brand_product_actions'.tr(),
          onSelected: (action) {
            if (action == 'edit') _showProductDialog(product: product);
            if (action == 'deactivate') _confirmDeactivate(product);
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text('brand_product_edit'.tr())),
            if (isActive) PopupMenuItem(value: 'deactivate', child: Text('brand_product_deactivate'.tr())),
          ],
        ),
      ),
    );
  }

  Future<void> _showProductDialog({Map<String, dynamic>? product}) async {
    final isEditing = product != null;
    var name = (product?['name'] ?? '').toString();
    var imageUrl = (product?['imageUrl'] ?? '').toString();
    var barcode = (product?['barcode'] ?? '').toString();
    var selectingImage = false;
    String? validationError;
    final barcodeFieldKey = GlobalKey<FormFieldState<String>>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'brand_product_edit_title'.tr() : 'brand_add_product'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('brand-product-name'),
                  initialValue: name,
                  onChanged: (value) => name = value,
                  decoration: InputDecoration(labelText: 'brand_product_name'.tr(), errorText: validationError),
                ),
                TextFormField(
                  key: const Key('brand-product-image'),
                  initialValue: imageUrl,
                  onChanged: (value) => imageUrl = value,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(labelText: 'brand_image_url_optional'.tr()),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('brand-product-select-image'),
                  onPressed: selectingImage
                      ? null
                      : () async {
                          setDialogState(() => selectingImage = true);
                          try {
                            final selectedUrl = await (widget.imageSelector ?? _pickAndUploadImage)();
                            if (selectedUrl != null && selectedUrl.isNotEmpty) setDialogState(() => imageUrl = selectedUrl);
                          } finally {
                            if (context.mounted) setDialogState(() => selectingImage = false);
                          }
                        },
                  icon: selectingImage
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_library_outlined),
                  label: Text(imageUrl.isEmpty ? 'brand_product_select_image'.tr() : 'brand_product_image_selected'.tr()),
                ),
                KeyedSubtree(
                  key: const Key('brand-product-barcode'),
                  child: TextFormField(
                    key: barcodeFieldKey,
                    initialValue: barcode,
                    onChanged: (value) => barcode = value,
                    decoration: InputDecoration(
                      labelText: 'brand_barcode_optional'.tr(),
                      suffixIcon: IconButton(
                        key: const Key('brand-product-scan-barcode'),
                        tooltip: 'brand_product_scan_barcode'.tr(),
                        onPressed: () async {
                          final value = await (widget.barcodeSelector ?? _scanBarcode)();
                          if (value == null || value.isEmpty) return;
                          barcode = value;
                          barcodeFieldKey.currentState?.didChange(value);
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('cancel'.tr())),
            FilledButton(
              key: const Key('brand-product-save'),
              onPressed: () async {
                final trimmedName = name.trim();
                if (trimmedName.isEmpty) {
                  setDialogState(() => validationError = 'brand_product_name_required'.tr());
                  return;
                }
                if (isEditing) {
                  await widget.updateProduct(productId: (product['id'] ?? '').toString(), name: trimmedName, imageUrl: imageUrl.trim(), barcode: barcode.trim());
                } else {
                  await widget.createProduct(name: trimmedName, imageUrl: imageUrl.trim(), barcode: barcode.trim());
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await widget.reload();
              },
              child: Text('save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('brand_product_deactivate_title'.tr()),
        content: Text('brand_product_deactivate_message'.tr(namedArgs: {'name': (product['name'] ?? '-').toString()})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text('cancel'.tr())),
          FilledButton(
            key: const Key('brand-product-confirm-deactivate'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('brand_product_deactivate'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.deactivateProduct((product['id'] ?? '').toString());
    await widget.reload();
  }

  Future<String?> _pickAndUploadImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return null;
    return CompanyServerService.uploadImageBytes(await image.readAsBytes());
  }

  Future<String?> _scanBarcode() {
    return Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _ProductBarcodeScannerScreen()));
  }
}

class _ProductBarcodeScannerScreen extends StatefulWidget {
  const _ProductBarcodeScannerScreen();

  @override
  State<_ProductBarcodeScannerScreen> createState() => _ProductBarcodeScannerScreenState();
}

class _ProductBarcodeScannerScreenState extends State<_ProductBarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _handled = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('brand_product_scan_barcode'.tr())),
      body: MobileScanner(controller: _controller, onDetect: _onDetect),
    );
  }
}