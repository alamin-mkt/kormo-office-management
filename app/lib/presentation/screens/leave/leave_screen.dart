import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/approval_card.dart';
import '../../widgets/kormo_data_table.dart';
import '../../widgets/stat_card.dart';

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> {
  void _showApplyLeaveDialog() {
    final leaveState = ref.read(leaveProvider);
    final types = leaveState.leaveTypes;

    if (types.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leave types configured')),
      );
      return;
    }

    String selectedTypeId = types.first.id;
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 1));
    bool isHalfDay = false;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Apply for Leave', style: TextStyle(fontWeight: FontWeight.bold)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedTypeId,
                    decoration: const InputDecoration(labelText: 'Leave Type *'),
                    items: types.map((t) {
                      return DropdownMenuItem(value: t.id, child: Text('${t.name} (${t.code})'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedTypeId = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogCtx,
                              initialDate: startDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) endDate = startDate;
                              });
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd MMM yyyy').format(startDate)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('to'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: dialogCtx,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => endDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(DateFormat('dd MMM yyyy').format(endDate)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    title: const Text('Half-day Leave'),
                    value: isHalfDay,
                    onChanged: (val) => setDialogState(() => isHalfDay = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason for Leave *',
                      hintText: 'Please detail reason for absence...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().isEmpty) return;

                Navigator.pop(ctx);
                final success = await ref.read(leaveProvider.notifier).applyLeave(
                      leaveTypeId: selectedTypeId,
                      startDate: startDate,
                      endDate: endDate,
                      isHalfDay: isHalfDay,
                      reason: reasonController.text.trim(),
                    );

                if (!mounted) return;
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('Leave application submitted for approval.'),
                    ),
                  );
                }
              },
              child: const Text('Submit Application'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);
    final authState = ref.watch(authProvider);
    final role = authState.role;

    final pendingApprovals = leaveState.requests.where((r) => r.status == LeaveStatus.pending).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Yearly leave balances, applications, and multi-tier approval workflows', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                  onPressed: _showApplyLeaveDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Apply for Leave'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Leave Balances Cards Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final cardWidth = isWide ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: const StatCard(
                        title: 'Annual Leave (AL)',
                        value: '14.0 Days',
                        icon: Icons.beach_access,
                        color: AppColors.primaryTeal,
                        subtitle: 'Remaining quota',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const StatCard(
                        title: 'Casual Leave (CL)',
                        value: '10.0 Days',
                        icon: Icons.event_available,
                        color: AppColors.success,
                        subtitle: 'Remaining quota',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const StatCard(
                        title: 'Sick Leave (SL)',
                        value: '14.0 Days',
                        icon: Icons.local_hospital,
                        color: AppColors.warning,
                        subtitle: 'Medical certificate needed >2d',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const StatCard(
                        title: 'Unpaid Leave (UL)',
                        value: '30.0 Days',
                        icon: Icons.money_off,
                        color: AppColors.muted,
                        subtitle: 'Leave without pay',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Pending Approvals Queue (If Manager / HR / Director)
            if (role != UserRole.employee && pendingApprovals.isNotEmpty) ...[
              const Text('Pending Approvals Queue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
              const SizedBox(height: 12),
              ...pendingApprovals.map((req) {
                return ApprovalCard(
                  title: '${req.leaveTypeName ?? "Leave"} Application',
                  requesterName: req.userName ?? 'Staff Member',
                  subtitle: '${req.totalDays} Day(s) • ${DateFormat("dd MMM yyyy").format(req.startDate)} - ${DateFormat("dd MMM yyyy").format(req.endDate)}',
                  reason: req.reason,
                  status: req.status.displayName,
                  onApprove: () => ref.read(leaveProvider.notifier).decideLeave(requestId: req.id, status: LeaveStatus.approved),
                  onReject: (comm) => ref.read(leaveProvider.notifier).decideLeave(requestId: req.id, status: LeaveStatus.rejected, comment: comm),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Leave Requests Table
            KormoDataTable(
              title: 'All Leave Applications & History',
              columns: const [
                KormoDataTableColumn(label: 'Applicant'),
                KormoDataTableColumn(label: 'Leave Type'),
                KormoDataTableColumn(label: 'Start Date'),
                KormoDataTableColumn(label: 'End Date'),
                KormoDataTableColumn(label: 'Duration'),
                KormoDataTableColumn(label: 'Status'),
                KormoDataTableColumn(label: 'Decided By'),
                KormoDataTableColumn(label: 'Action'),
              ],
              rows: leaveState.requests.map((req) {
                final startStr = DateFormat('dd MMM yyyy').format(req.startDate);
                final endStr = DateFormat('dd MMM yyyy').format(req.endDate);

                return [
                  Text(req.userName ?? 'Self', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(req.leaveTypeName ?? 'Annual Leave'),
                  Text(startStr),
                  Text(endStr),
                  Text('${req.totalDays} day(s)'),
                  _buildStatusChip(req.status.displayName),
                  Text(req.decidedByName ?? '--'),
                  if (req.status == LeaveStatus.pending)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => ref.read(leaveProvider.notifier).cancelLeave(req.id),
                      child: const Text('Cancel'),
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

  Widget _buildStatusChip(String status) {
    Color bg = AppColors.warningBg;
    Color fg = AppColors.orangeText;

    if (status == 'Approved') {
      bg = AppColors.successBg;
      fg = AppColors.success;
    } else if (status == 'Rejected' || status == 'Cancelled') {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
