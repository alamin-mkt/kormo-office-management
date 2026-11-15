import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/leave_model.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/admin_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/leave_provider.dart';
import '../../widgets/approval_card.dart';
import '../../widgets/live_presence_board.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/user_form_dialog.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final role = authState.role;
    final user = authState.profile;

    final attendanceState = ref.watch(attendanceProvider);
    final leaveState = ref.watch(leaveProvider);
    final adminState = ref.watch(adminProvider);

    final attendees = attendanceState.whoIsInNow;
    final totalStaff = adminState.employees.isNotEmpty ? adminState.employees.length : 6;
    final presentCount = attendees.length;
    final lateCount = attendanceState.history.where((a) => a.status.name == 'late').length;
    final pendingLeaves = leaveState.requests.where((r) => r.status.name == 'pending').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back, ${user?.fullName ?? "Colleague"}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Role: ${role.displayName} • Department: ${user?.departmentName ?? "Engineering"}',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
                if (role != UserRole.employee)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                    onPressed: () => UserFormDialog.show(context),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add User'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // 1. KPI STATS ROW (4 Cards)
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
                      child: StatCard(
                        title: 'Total Workforce',
                        value: '$totalStaff',
                        icon: Icons.people_outline,
                        color: AppColors.primaryTeal,
                        subtitle: 'Across all branches',
                        onTap: () => context.go('/users'),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Present Today',
                        value: '$presentCount',
                        icon: Icons.how_to_reg_outlined,
                        color: AppColors.success,
                        subtitle: 'Office attendance',
                        onTap: () => context.go('/attendance'),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Late Arrivals',
                        value: '$lateCount',
                        icon: Icons.timelapse_outlined,
                        color: AppColors.warning,
                        subtitle: 'Grace period exceeded',
                        onTap: () => context.go('/attendance'),
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Pending Approvals',
                        value: '${pendingLeaves.length}',
                        icon: Icons.pending_actions_outlined,
                        color: AppColors.accentOrange,
                        subtitle: 'Awaiting review',
                        onTap: () => context.go('/leave'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 2. TREND & LIVE PRESENCE BOARD ROW
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                return Flex(
                  direction: isWide ? Axis.horizontal : Axis.vertical,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Presence Board
                    Expanded(
                      flex: isWide ? 3 : 0,
                      child: LivePresenceBoard(attendees: attendees),
                    ),
                    if (isWide) const SizedBox(width: 16) else const SizedBox(height: 16),

                    // Quick Actions / Personal Punch Summary
                    Expanded(
                      flex: isWide ? 2 : 0,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Action Center',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                            ),
                            const SizedBox(height: 16),
                            // Orange Check-In / Out Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accentOrange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () => context.go('/attendance'),
                                icon: const Icon(Icons.fingerprint, size: 20),
                                label: Text(
                                  attendanceState.isCheckedIn ? 'Proceed to Check-Out' : 'Perform Check-In',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryTeal,
                                side: const BorderSide(color: AppColors.primaryTeal),
                                minimumSize: const Size(double.infinity, 44),
                              ),
                              onPressed: () => context.go('/leave'),
                              icon: const Icon(Icons.calendar_month, size: 18),
                              label: const Text('Apply for Leave'),
                            ),
                            const SizedBox(height: 12),
                            if (role == UserRole.director)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.info,
                                  side: const BorderSide(color: AppColors.info),
                                  minimumSize: const Size(double.infinity, 44),
                                ),
                                onPressed: () => context.go('/payroll'),
                                icon: const Icon(Icons.verified, size: 18),
                                label: const Text('Director Payroll Sign-off'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 3. APPROVALS QUEUE & NOTICES
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 960;

                final approvalsWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Approval Requests',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 12),
                    if (pendingLeaves.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Text('No pending approval requests.', style: TextStyle(color: AppColors.muted)),
                      )
                    else
                      ...pendingLeaves.take(3).map((r) {
                        return ApprovalCard(
                          title: '${r.leaveTypeName ?? "Leave"} Request',
                          requesterName: r.userName ?? 'Employee',
                          subtitle: '${r.totalDays} Day(s) • ${r.startDate.toIso8601String().split("T").first} to ${r.endDate.toIso8601String().split("T").first}',
                          reason: r.reason,
                          status: r.status.name,
                          onApprove: () {
                            ref.read(leaveProvider.notifier).decideLeave(
                                  requestId: r.id,
                                  status: LeaveStatus.approved,
                                );
                          },
                          onReject: (comment) {
                            ref.read(leaveProvider.notifier).decideLeave(
                                  requestId: r.id,
                                  status: LeaveStatus.rejected,
                                  comment: comment,
                                );
                          },
                        );
                      }),
                  ],
                );

                final noticesWidget = Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Company Notices',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink),
                          ),
                          InkWell(
                            onTap: () => context.go('/tasks'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text('View All', style: TextStyle(color: AppColors.primaryTeal, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildNoticeItem(
                        title: 'Office Schedule during Ramadan & Eid',
                        time: '2 hours ago',
                        isPinned: true,
                      ),
                      const Divider(),
                      _buildNoticeItem(
                        title: 'New Health Insurance Policy 2026',
                        time: 'Yesterday',
                        isPinned: false,
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: approvalsWidget),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: noticesWidget),
                    ],
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      approvalsWidget,
                      const SizedBox(height: 16),
                      noticesWidget,
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeItem({required String title, required String time, required bool isPinned}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPinned ? Icons.push_pin : Icons.article_outlined,
            size: 18,
            color: isPinned ? AppColors.accentOrange : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.subtle)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
