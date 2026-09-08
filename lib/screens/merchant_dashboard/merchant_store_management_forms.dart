part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

extension _MerchantStoreManagementFormsExt on _MerchantDashboardScreenState {
  Widget _buildStoreManagementForms() {
    return Column(
      children: [
        _mutableSection(
          ExpansionTile(
            title: Text('merchant_create_branch'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _branchNameController,
                decoration: InputDecoration(labelText: 'merchant_name'.tr()),
              ),
              TextField(
                controller: _branchAddressController,
                decoration: InputDecoration(labelText: 'merchant_address'.tr()),
              ),
              TextField(
                controller: _branchLocationController,
                decoration: InputDecoration(labelText: 'merchant_location'.tr()),
                readOnly: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickBranchLocation,
                icon: const Icon(Icons.map_outlined),
                label: Text('merchant_pick_branch_location'.tr()),
              ),
              if (_branchLatitude != null && _branchLongitude != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'merchant_branch_geo_selected'.tr(namedArgs: {
                      'lat': _branchLatitude!.toStringAsFixed(6),
                      'lng': _branchLongitude!.toStringAsFixed(6),
                    }),
                  ),
                ),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _createBranch, child: Text('create'.tr())),
            ],
          ),
        ),
        _mutableSection(
          ExpansionTile(
            title: Text('merchant_assign_manager_permissions'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              DropdownButtonFormField<String>(
                initialValue: () {
                  final current = _managerBranchIdController.text.trim();
                  if (current.isEmpty) return null;
                  final exists = _branches.any((b) => (b['id'] ?? '').toString() == current);
                  return exists ? current : null;
                }(),
                items: _branches
                    .map(
                      (branch) => DropdownMenuItem<String>(
                        value: (branch['id'] ?? '').toString(),
                        child: Text(
                          '${branch['name'] ?? 'Branch'} (${branch['id'] ?? ''})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  _managerBranchIdController.text = (value ?? '').trim();
                  setState(() {});
                },
                decoration: InputDecoration(labelText: 'merchant_branch'.tr()),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _managerBranchIdController,
                decoration: InputDecoration(labelText: 'merchant_branch_id'.tr()),
              ),
              TextField(
                controller: _managerUserIdController,
                decoration: InputDecoration(labelText: 'merchant_manager_user_id'.tr()),
              ),
              SwitchListTile(
                value: _canReviewInvoices,
                title: Text('merchant_can_review_invoices'.tr()),
                onChanged: (value) => setState(() => _canReviewInvoices = value),
              ),
              SwitchListTile(
                value: _canCreateOffers,
                title: Text('merchant_can_create_offers'.tr()),
                onChanged: (value) => setState(() => _canCreateOffers = value),
              ),
              SwitchListTile(
                value: _canManageGroup,
                title: Text('merchant_can_manage_group'.tr()),
                onChanged: (value) => setState(() => _canManageGroup = value),
              ),
              SwitchListTile(
                value: _canViewReports,
                title: Text('merchant_can_view_reports'.tr()),
                onChanged: (value) => setState(() => _canViewReports = value),
              ),
              SwitchListTile(
                value: _canViewSettlements,
                title: Text('merchant_can_view_settlements'.tr()),
                onChanged: (value) => setState(() => _canViewSettlements = value),
              ),
              SwitchListTile(
                value: _canAddCashiers,
                title: Text('merchant_can_add_cashiers'.tr()),
                onChanged: (value) => setState(() => _canAddCashiers = value),
              ),
              SwitchListTile(
                value: _canReplyReports,
                title: Text('merchant_can_reply_reports'.tr()),
                onChanged: (value) => setState(() => _canReplyReports = value),
              ),
              ElevatedButton(onPressed: _addManager, child: Text('merchant_save_manager_permissions'.tr())),
            ],
          ),
        ),
        _mutableSection(
          ExpansionTile(
            title: Text('merchant_bind_cashier'.tr()),
            childrenPadding: const EdgeInsets.all(12),
            children: [
              TextField(
                controller: _cashierBranchIdController,
                decoration: InputDecoration(labelText: 'merchant_branch_id'.tr()),
              ),
              TextField(
                controller: _cashierUserIdController,
                decoration: InputDecoration(labelText: 'merchant_cashier_user_id'.tr()),
              ),
              ElevatedButton(onPressed: _bindCashier, child: Text('merchant_bind_cashier_action'.tr())),
            ],
          ),
        ),
      ],
    );
  }
}
