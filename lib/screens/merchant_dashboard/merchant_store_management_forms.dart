part of 'package:coupona_app/screens/merchant_dashboard_screen.dart';

extension _MerchantStoreManagementFormsExt on _MerchantDashboardScreenState {
  Widget _buildStoreManagementForms() {
    return Column(
      children: [
        if (_result != null && _result!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: const Color(0xFFF8FAFC),
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: kMerchantBrandGreen),
                title: Text(_result!),
              ),
            ),
          ),
        _mutableSection(
          Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.groups_outlined, color: kTeal),
                  title: Text(_tx('merchant_team_title', 'فريق العمل')),
                  subtitle: Text(_tx('merchant_team_open_hint', 'إدارة أعضاء الفريق والصلاحيات')),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MerchantTeamScreen(branches: _branches),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ExpansionTile(
                  key: const Key('merchant-create-branch-tile'),
                  leading: const Icon(Icons.storefront_outlined, color: kTeal),
                  title: Text(_tx('merchant_create_branch', 'إنشاء فرع جديد')),
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
                const Divider(height: 1),
                ExpansionTile(
                  key: const Key('merchant-assign-manager-tile'),
                  leading: const Icon(Icons.admin_panel_settings_outlined, color: kTeal),
                  title: Text(_tx('merchant_assign_manager_permissions', 'تعيين مدير الفرع والصلاحيات')),
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
                        _updateFormState(() {});
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
                      title: Text(_tx('merchant_permission_canReviewInvoices', 'مراجعة الفواتير')),
                      onChanged: (value) => _updateFormState(() => _canReviewInvoices = value),
                    ),
                    SwitchListTile(
                      value: _canCreateOffers,
                      title: Text(_tx('merchant_permission_canCreateOffers', 'إنشاء وتعديل العروض')),
                      onChanged: (value) => _updateFormState(() => _canCreateOffers = value),
                    ),
                    SwitchListTile(
                      value: _canManageGroup,
                      title: Text(_tx('merchant_permission_canManageGroup', 'إدارة المجموعة والأعضاء')),
                      onChanged: (value) => _updateFormState(() => _canManageGroup = value),
                    ),
                    SwitchListTile(
                      value: _canViewReports,
                      title: Text(_tx('merchant_permission_canViewReports', 'عرض التقارير والإحصائيات')),
                      onChanged: (value) => _updateFormState(() => _canViewReports = value),
                    ),
                    SwitchListTile(
                      value: _canViewSettlements,
                      title: Text(_tx('merchant_permission_canViewSettlements', 'عرض التسويات والحسابات')),
                      onChanged: (value) => _updateFormState(() => _canViewSettlements = value),
                    ),
                    SwitchListTile(
                      value: _canAddCashiers,
                      title: Text(_tx('merchant_permission_canAddCashiers', 'إضافة وتعيين الكاشيرين')),
                      onChanged: (value) => _updateFormState(() => _canAddCashiers = value),
                    ),
                    SwitchListTile(
                      value: _canReplyReports,
                      title: Text(_tx('merchant_permission_canReplyReports', 'الرد على التقارير والبلاغات')),
                      onChanged: (value) => _updateFormState(() => _canReplyReports = value),
                    ),
                    ElevatedButton(onPressed: _addManager, child: Text('merchant_save_manager_permissions'.tr())),
                  ],
                ),
                const Divider(height: 1),
                ExpansionTile(
                  key: const Key('merchant-bind-cashier-tile'),
                  leading: const Icon(Icons.badge_outlined, color: kTeal),
                  title: Text(_tx('merchant_bind_cashier', 'ربط الكاشير بالفرع')),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: () {
                        final current = _cashierBranchIdController.text.trim();
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
                        _cashierBranchIdController.text = (value ?? '').trim();
                        _updateFormState(() {});
                      },
                      decoration: InputDecoration(labelText: 'merchant_branch'.tr()),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _cashierBranchIdController,
                      decoration: InputDecoration(labelText: 'merchant_branch_id'.tr()),
                    ),
                    TextField(
                      controller: _cashierUserIdController,
                      decoration: InputDecoration(
                        labelText: _tx('cashier_phone_or_id_label', 'رقم هاتف الكاشير أو معرف المستخدم *'),
                        hintText: '09xxxxxxxx / User ID',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _bindCashier, child: Text('merchant_bind_cashier_action'.tr())),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
