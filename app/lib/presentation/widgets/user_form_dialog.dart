import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/profile_model.dart';
import '../providers/admin_provider.dart';
import '../providers/auth_provider.dart';

class UserFormDialog extends ConsumerStatefulWidget {
  final String? defaultDepartmentId;

  const UserFormDialog({super.key, this.defaultDepartmentId});

  static Future<void> show(BuildContext context, {String? defaultDepartmentId}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UserFormDialog(defaultDepartmentId: defaultDepartmentId),
    );
  }

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeeIdController = TextEditingController();
  final _designationController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.employee;
  String? _selectedDepartmentId;
  String? _selectedBranchId;
  String? _selectedShiftId;
  final bool _isAutoPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDepartmentId = widget.defaultDepartmentId;
    _generateRandomPassword();
    _generateAutoEmployeeId();
  }

  void _generateRandomPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$';
    final rand = Random.secure();
    final pwd = List.generate(10, (index) => chars[rand.nextInt(chars.length)]).join();
    _passwordController.text = 'Kormo@$pwd';
  }

  void _generateAutoEmployeeId() {
    final randNum = 100 + Random().nextInt(899);
    _employeeIdController.text = 'EMP-$randNum';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeeIdController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  List<UserRole> _getAllowedRoles(UserRole callerRole) {
    switch (callerRole) {
      case UserRole.director:
        return [UserRole.admin, UserRole.hr, UserRole.manager, UserRole.executive, UserRole.employee];
      case UserRole.admin:
        return [UserRole.hr, UserRole.manager, UserRole.executive, UserRole.employee];
      case UserRole.hr:
        return [UserRole.manager, UserRole.executive, UserRole.employee];
      case UserRole.manager:
        return [UserRole.executive, UserRole.employee];
      case UserRole.executive:
        return [UserRole.employee];
      case UserRole.employee:
        return [];
    }
  }

  Future<void> _submitSingleUser() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(adminProvider.notifier).createUser(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      role: _selectedRole,
      departmentId: _selectedDepartmentId,
      branchId: _selectedBranchId,
      shiftId: _selectedShiftId,
      designation: _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
      employeeId: _employeeIdController.text.trim(),
    );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Employee successfully created! Temporary password assigned.'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final adminState = ref.watch(adminProvider);
    final callerRole = authState.role;
    final allowedRoles = _getAllowedRoles(callerRole);

    if (allowedRoles.isEmpty) {
      return AlertDialog(
        title: const Text('Access Restricted'),
        content: const Text('Your role does not have permission to add new users.'),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    }

    if (!allowedRoles.contains(_selectedRole) && allowedRoles.isNotEmpty) {
      _selectedRole = allowedRoles.last;
    }

    final isManagerOrExec = callerRole == UserRole.manager || callerRole == UserRole.executive;
    if (isManagerOrExec && authState.profile?.departmentId != null) {
      _selectedDepartmentId = authState.profile!.departmentId;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.tealBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_add, color: AppColors.primaryTeal),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add New Employee',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.muted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tabs: Single Add vs Bulk CSV (for HR/Admin/Director)
              if (callerRole == UserRole.director || callerRole == UserRole.admin || callerRole == UserRole.hr)
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primaryTeal,
                  indicatorColor: AppColors.primaryTeal,
                  tabs: const [
                    Tab(icon: Icon(Icons.person, size: 18), text: 'Single Form'),
                    Tab(icon: Icon(Icons.upload_file, size: 18), text: 'Bulk CSV Import'),
                  ],
                ),

              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Single User Form
                    Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (adminState.errorMessage != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.dangerBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                                ),
                                child: Text(
                                  adminState.errorMessage!,
                                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                                ),
                              ),

                            // Row 1: Full Name & Employee ID
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _fullNameController,
                                    decoration: const InputDecoration(labelText: 'Full Name *', hintText: 'e.g. Rahim Chowdhury'),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _employeeIdController,
                                    decoration: const InputDecoration(labelText: 'Employee ID *', hintText: 'KORMO-101'),
                                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 2: Email & Phone
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'rahim@company.com'),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return 'Required';
                                      if (!val.contains('@')) return 'Invalid email';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: const InputDecoration(labelText: 'Phone Number', hintText: '+880 1700-000000'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 3: Role & Designation
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<UserRole>(
                                    value: _selectedRole,
                                    decoration: const InputDecoration(labelText: 'System Role *'),
                                    items: allowedRoles.map((r) {
                                      return DropdownMenuItem(value: r, child: Text(r.displayName));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setState(() => _selectedRole = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _designationController,
                                    decoration: const InputDecoration(labelText: 'Designation / Job Title', hintText: 'Software Engineer'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 4: Department & Branch
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedDepartmentId,
                                    decoration: InputDecoration(
                                      labelText: isManagerOrExec ? 'Department (Own Dept)' : 'Department *',
                                    ),
                                    items: adminState.departments.map((d) {
                                      return DropdownMenuItem<String>(
                                        value: d['id'].toString(),
                                        child: Text(d['name'].toString()),
                                      );
                                    }).toList(),
                                    onChanged: isManagerOrExec
                                        ? null // locked to manager's own dept
                                        : (val) => setState(() => _selectedDepartmentId = val),
                                    validator: (val) => val == null ? 'Select department' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedBranchId,
                                    decoration: const InputDecoration(labelText: 'Office Branch *'),
                                    items: adminState.branches.map((b) {
                                      return DropdownMenuItem<String>(
                                        value: b['id'].toString(),
                                        child: Text(b['name'].toString()),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setState(() => _selectedBranchId = val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Row 5: Shift Selection
                            DropdownButtonFormField<String>(
                              value: _selectedShiftId,
                              decoration: const InputDecoration(labelText: 'Assigned Work Shift *'),
                              items: adminState.shifts.map((s) {
                                return DropdownMenuItem<String>(
                                  value: s['id'].toString(),
                                  child: Text('${s['name']} (${s['start_time']} - ${s['end_time']})'),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedShiftId = val),
                            ),
                            const SizedBox(height: 14),

                            // Temporary Password Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _passwordController,
                                      readOnly: _isAutoPassword,
                                      decoration: const InputDecoration(
                                        labelText: 'Initial Temporary Password',
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Regenerate Password',
                                    icon: const Icon(Icons.refresh, color: AppColors.primaryTeal),
                                    onPressed: _generateRandomPassword,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bulk CSV Import View
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, size: 48, color: AppColors.primaryTeal),
                            const SizedBox(height: 16),
                            const Text(
                              'Bulk CSV Employee Import',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Upload a CSV file containing columns: employee_id, full_name, email, phone, role, department_code, branch_code.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.muted),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('CSV Parser ready. Select CSV file to import.')),
                                );
                              },
                              icon: const Icon(Icons.file_upload),
                              label: const Text('Select CSV File'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),

              // Modal Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: adminState.isLoading ? null : _submitSingleUser,
                    child: adminState.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Create User'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
