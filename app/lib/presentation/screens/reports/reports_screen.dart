import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/kormo_data_table.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _sampleAuditLogs = [
    {
      'time': '15 Nov 2026, 11:42 AM',
      'actor': 'Syed Rahman (Director)',
      'action': 'APPROVE_PAYROLL_RUN',
      'table': 'payroll_runs',
      'platform': 'web',
      'details': 'Approved and locked October 2026 payroll run (428,000 BDT).',
    },
    {
      'time': '15 Nov 2026, 10:15 AM',
      'actor': 'Tariq Hasan (Admin)',
      'action': 'CREATE_USER',
      'table': 'profiles',
      'platform': 'web',
      'details': 'Created employee account for Fatima Zohra (KORMO-006) in Engineering dept.',
    },
    {
      'time': '14 Nov 2026, 04:30 PM',
      'actor': 'Nasreen Akter (HR)',
      'action': 'DECIDE_LEAVE',
      'table': 'leave_requests',
      'platform': 'web',
      'details': 'Approved 2.0 days Casual Leave for Tanvir Ahmed.',
    },
    {
      'time': '14 Nov 2026, 09:05 AM',
      'actor': 'Mahmudul Haque (Manager)',
      'action': 'TRANSFER_DEPARTMENT',
      'table': 'profiles',
      'platform': 'web',
      'details': 'Updated department assignment to Engineering IT.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    Text('Reports & Immutable Audit Trail', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Generate compliance reports and inspect tamper-proof system audit logs', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Exporting master compliance audit file...')),
                    );
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Export All Audit Logs'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryTeal,
              indicatorColor: AppColors.primaryTeal,
              tabs: const [
                Tab(icon: Icon(Icons.security), text: 'Immutable Audit Trail'),
                Tab(icon: Icon(Icons.analytics), text: 'Analytics & Compliance Reports'),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              height: 580,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Immutable Audit Trail Table
                  KormoDataTable(
                    title: 'System Mutation Logs (Zero UPDATE or DELETE Allowed)',
                    onExportCsv: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Downloading CSV Audit Trail...')),
                      );
                    },
                    columns: const [
                      KormoDataTableColumn(label: 'Timestamp (Asia/Dhaka)'),
                      KormoDataTableColumn(label: 'Actor'),
                      KormoDataTableColumn(label: 'Action Code'),
                      KormoDataTableColumn(label: 'Target Entity'),
                      KormoDataTableColumn(label: 'Platform'),
                      KormoDataTableColumn(label: 'Details & JSON State'),
                    ],
                    rows: _sampleAuditLogs.map((log) {
                      return [
                        Text(log['time'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(log['actor']),
                        _buildActionTag(log['action']),
                        Text(log['table']),
                        _buildPlatformChip(log['platform']),
                        Text(log['details'], style: const TextStyle(fontSize: 12)),
                      ];
                    }).toList(),
                  ),

                  // Tab 2: Analytics & Reports
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Available Executive Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          title: 'Monthly Punctuality & Attendance Summary',
                          desc: 'Aggregated work hours, lates, overtime, and absenteeism breakdown across branches.',
                          icon: Icons.timer,
                        ),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          title: 'Leave Utilization & Statutory Balances',
                          desc: 'Comprehensive annual, casual, and medical leave usage report per department.',
                          icon: Icons.event_available,
                        ),
                        const SizedBox(height: 12),
                        _buildReportCard(
                          title: 'Payroll Expense & Deduction Audit',
                          desc: 'Full tax, unpaid absence, and net disbursement ledger for accounts compliance.',
                          icon: Icons.receipt_long,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({required String title, required String desc, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.tealBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppColors.primaryTeal, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Generating $title (CSV + PDF)...')),
              );
            },
            icon: const Icon(Icons.file_download, size: 16),
            label: const Text('Generate'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTag(String action) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action,
        style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildPlatformChip(String platform) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        platform.toUpperCase(),
        style: const TextStyle(color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
