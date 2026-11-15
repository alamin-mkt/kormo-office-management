import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/kormo_data_table.dart';
import '../../widgets/user_form_dialog.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  void _showDeactivateDialog(BuildContext context, WidgetRef ref, ProfileModel emp) {
    final reasonController = TextEditingController();
    final isCurrentlyActive = emp.isActive;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCurrentlyActive ? 'Deactivate Employee' : 'Reactivate Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to ${isCurrentlyActive ? "deactivate" : "reactivate"} ${emp.fullName} (${emp.employeeId})?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Audit Logged) *',
                hintText: 'Enter reason for status change...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? AppColors.danger : AppColors.success,
            ),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(adminProvider.notifier).toggleUserStatus(
                    emp.id,
                    !isCurrentlyActive,
                    reasonController.text.trim(),
                  );
            },
            child: Text(isCurrentlyActive ? 'Confirm Deactivate' : 'Confirm Reactivate'),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, ProfileModel emp) {
    final adminState = ref.read(adminProvider);
    String? selectedDeptId = emp.departmentId ?? (adminState.departments.isNotEmpty ? adminState.departments.first['id'] : null);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Transfer Department: ${emp.fullName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Department: ${emp.departmentName ?? "Unassigned"}'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedDeptId,
                decoration: const InputDecoration(labelText: 'New Target Department *'),
                items: adminState.departments.map((d) {
                  return DropdownMenuItem<String>(
                    value: d['id'].toString(),
                    child: Text(d['name'].toString()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDeptId = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedDeptId == null) return;
                Navigator.pop(ctx);
                await ref.read(adminProvider.notifier).transferDepartment(
                      userId: emp.id,
                      newDepartmentId: selectedDeptId!,
                    );
              },
              child: const Text('Confirm Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminProvider);
    final authState = ref.watch(authProvider);
    final callerRole = authState.role;

    final canManage = callerRole == UserRole.director || callerRole == UserRole.admin || callerRole == UserRole.hr;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Employee Directory', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Manage staff records, departments, designations, and account access', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                if (callerRole != UserRole.employee)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                    onPressed: () => UserFormDialog.show(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add User'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Employee Directory Table
            KormoDataTable(
              title: 'All Active & Registered Personnel',
              columns: const [
                KormoDataTableColumn(label: 'Staff Member'),
                KormoDataTableColumn(label: 'Employee ID'),
                KormoDataTableColumn(label: 'Role'),
                KormoDataTableColumn(label: 'Department'),
                KormoDataTableColumn(label: 'Branch'),
                KormoDataTableColumn(label: 'Work Shift'),
                KormoDataTableColumn(label: 'Status'),
                KormoDataTableColumn(label: 'Actions'),
              ],
              rows: adminState.employees.map((emp) {
                return [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.tealBg,
                        child: Text(
                          emp.fullName.isNotEmpty ? emp.fullName[0].toUpperCase() : 'U',
                          style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(emp.email, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  Text(emp.employeeId, style: const TextStyle(fontWeight: FontWeight.w600)),
                  _buildRoleBadge(emp.role),
                  Text(emp.departmentName ?? 'General'),
                  Text(emp.branchName ?? 'HQ Banani'),
                  Text(emp.shiftName ?? 'General Shift'),
                  _buildStatusChip(emp.isActive),
                  if (canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onSelected: (val) {
                        if (val == 'transfer') {
                          _showTransferDialog(context, ref, emp);
                        } else if (val == 'toggle_status') {
                          _showDeactivateDialog(context, ref, emp);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'transfer', child: Text('Transfer Department')),
                        PopupMenuItem(
                          value: 'toggle_status',
                          child: Text(emp.isActive ? 'Deactivate Account' : 'Reactivate Account'),
                        ),
                      ],
                    )
                  else
                    const Text('--'),
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tealBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        role.displayName,
        style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.successBg : AppColors.dangerBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? 'Active' : 'Disabled',
        style: TextStyle(
          color: isActive ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
