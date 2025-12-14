import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/firestore/product_repository.dart';

class MerchantProductsScreen extends StatefulWidget {
  final String merchantId;
  const MerchantProductsScreen({super.key, required this.merchantId});

  @override
  State<MerchantProductsScreen> createState() => _MerchantProductsScreenState();
}

class _MerchantProductsScreenState extends State<MerchantProductsScreen> {
  late final ProductRepository _productRepository;

  @override
  void initState() {
    super.initState();
    _productRepository = ProductRepository();
  }

  Future<void> _confirmDelete(Product product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('merchant_products_confirm_delete_title'.tr()),
        content: Text('merchant_products_confirm_delete_message'.tr(args: [product.name])),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _productRepository.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_products_deleted'.tr(args: [product.name]))),
      );
    }
  }

  void _openProductForm({Product? product}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: _MerchantProductForm(
            merchantId: widget.merchantId,
            productRepository: _productRepository,
            product: product,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('merchant_products_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openProductForm(),
        icon: const Icon(Icons.add),
        label: Text('merchant_products_add'.tr()),
      ),
      body: StreamBuilder<List<Product>>(
        stream: _productRepository.watchProducts(widget.merchantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('merchant_products_error'.tr()));
          }
          final products = snapshot.data ?? const [];
          if (products.isEmpty) {
            return Center(child: Text('merchant_products_empty'.tr()));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, index) {
              final product = products[index];
              return Card(
                child: ListTile(
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.description != null && product.description!.isNotEmpty)
                        Text(product.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text('merchant_products_price_fmt'.tr(args: [product.price.toStringAsFixed(2)])),
                      Text('merchant_products_points_fmt'.tr(args: [product.pointsPerUnit.toStringAsFixed(1)])),
                    ],
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'edit'.tr(),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openProductForm(product: product),
                      ),
                      IconButton(
                        tooltip: 'delete'.tr(),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(product),
                      ),
                      Switch(
                        value: product.isActive,
                        onChanged: (value) {
                          final updated = Product(
                            id: product.id,
                            merchantId: product.merchantId,
                            name: product.name,
                            description: product.description,
                            price: product.price,
                            category: product.category,
                            brandId: product.brandId,
                            pointsPerUnit: product.pointsPerUnit,
                            isActive: value,
                          );
                          _productRepository.saveProduct(updated);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: products.length,
          );
        },
      ),
    );
  }
}

class _MerchantProductForm extends StatefulWidget {
  final String merchantId;
  final ProductRepository productRepository;
  final Product? product;
  const _MerchantProductForm({
    required this.merchantId,
    required this.productRepository,
    this.product,
  });

  @override
  State<_MerchantProductForm> createState() => _MerchantProductFormState();
}

class _MerchantProductFormState extends State<_MerchantProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _brandController;
  late final TextEditingController _pointsController;
  bool _isActive = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _descriptionController = TextEditingController(text: product?.description ?? '');
    _priceController = TextEditingController(text: product != null ? product.price.toString() : '');
    _categoryController = TextEditingController(text: product?.category ?? '');
    _brandController = TextEditingController(text: product?.brandId ?? '');
    _pointsController = TextEditingController(text: product != null ? product.pointsPerUnit.toString() : '');
    _isActive = product?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _brandController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final product = Product(
        id: widget.product?.id ?? '',
        merchantId: widget.merchantId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0,
        category: _categoryController.text.trim(),
        brandId: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
        pointsPerUnit: double.tryParse(_pointsController.text.trim()) ?? 0,
        isActive: _isActive,
      );
      if (widget.product == null) {
        await widget.productRepository.addProduct(product);
      } else {
        await widget.productRepository.saveProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('merchant_products_save_error'.tr())),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing ? 'merchant_products_edit_title'.tr() : 'merchant_products_add_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'merchant_products_field_name'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'merchant_products_field_description'.tr()),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'merchant_products_field_price'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(labelText: 'merchant_products_field_category'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brandController,
              decoration: InputDecoration(labelText: 'merchant_products_field_brand'.tr()),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'merchant_products_field_points'.tr()),
              validator: (value) => value == null || value.trim().isEmpty ? 'field_required'.tr() : null,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              title: Text('merchant_products_field_active'.tr()),
              onChanged: (value) => setState(() => _isActive = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: Text('cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _save,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('save'.tr()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
