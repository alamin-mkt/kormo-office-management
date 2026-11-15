import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/profile_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/kormo_data_table.dart';
import '../../widgets/stat_card.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  const PayrollScreen({super.key});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends ConsumerState<PayrollScreen> {
  final List<Map<String, dynamic>> _sampleRuns = [
    {
      'id': 'run_2026_11',
      'month': 11,
      'month_name': 'November 2026',
      'year': 2026,
      'gross': 480000.0,
      'deductions': 56000.0,
      'net': 424000.0,
      'status': 'draft',
      'employees': 6,
    },
    {
      'id': 'run_2026_10',
      'month': 10,
      'month_name': 'October 2026',
      'year': 2026,
      'gross': 480000.0,
      'deductions': 52000.0,
      'net': 428000.0,
      'status': 'locked',
      'employees': 6,
    },
  ];

  final List<Map<String, dynamic>> _samplePayslips = [
    {
      'emp_id': 'KORMO-001',
      'name': 'Syed Rahman (Director)',
      'base': 150000.0,
      'allowances': 100000.0,
      'ot': 0.0,
      'deductions': 25000.0,
      'net': 225000.0,
      'status': 'approved',
    },
    {
      'emp_id': 'KORMO-002',
      'name': 'Tariq Hasan (Admin)',
      'base': 95000.0,
      'allowances': 61000.0,
      'ot': 0.0,
      'deductions': 12000.0,
      'net': 144000.0,
      'status': 'approved',
    },
    {
      'emp_id': 'KORMO-003',
      'name': 'Nasreen Akter (HR Lead)',
      'base': 85000.0,
      'allowances': 57000.0,
      'ot': 0.0,
      'deductions': 10000.0,
      'net': 132000.0,
      'status': 'approved',
    },
    {
      'emp_id': 'KORMO-006',
      'name': 'Fatima Zohra (Software Eng)',
      'base': 45000.0,
      'allowances': 31000.0,
      'ot': 3240.0,
      'deductions': 3000.0,
      'net': 76240.0,
      'status': 'approved',
    },
  ];

  String _formatCurrency(double val) {
    return '৳ ${NumberFormat("#,##,##0.00").format(val)}';
  }

  void _showRunPayrollModal() {
    int month = DateTime.now().month;
    int year = DateTime.now().year;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate Monthly Payroll'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Automated payroll will compute base salary, attendance deductions, unpaid leaves, and overtime pay for all active personnel.'),
            const SizedBox(height: 16),
            Text('Payroll Period: ${DateFormat('MMMM yyyy').format(DateTime(year, month))}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: AppColors.success, content: Text('Draft payroll calculated successfully for current month.')),
              );
            },
            child: const Text('Calculate Draft Payroll'),
          ),
        ],
      ),
    );
  }

  void _showDirectorApproveModal(Map<String, dynamic> run) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Director Sign-Off & Permanent Lock'),
        content: Text('Are you sure you want to approve and lock the payroll for ${run["month_name"]}? Once locked, records are strictly immutable and protected by database triggers.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () {
              setState(() {
                run['status'] = 'locked';
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: AppColors.success, content: Text('Payroll run approved and permanently locked.')),
              );
            },
            child: const Text('Approve & Lock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final role = authState.role;

    final isDirector = role == UserRole.director;
    final canManage = isDirector || role == UserRole.admin || role == UserRole.hr;

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
                    Text('Payroll & Compensation', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink)),
                    SizedBox(height: 4),
                    Text('Automated attendance deductions, overtime computations, Director sign-off, and PDF payslips', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
                if (canManage)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                    onPressed: _showRunPayrollModal,
                    icon: const Icon(Icons.calculate, size: 18),
                    label: const Text('Run Payroll'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Financial Summary KPI Row
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
                        title: 'Total Gross Payout',
                        value: _formatCurrency(480000.0),
                        icon: Icons.account_balance,
                        color: AppColors.primaryTeal,
                        subtitle: 'Current monthly run',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Total Deductions',
                        value: _formatCurrency(56000.0),
                        icon: Icons.trending_down,
                        color: AppColors.danger,
                        subtitle: 'Tax, late, unpaid leave',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: StatCard(
                        title: 'Net Salary Disbursed',
                        value: _formatCurrency(424000.0),
                        icon: Icons.payments,
                        color: AppColors.success,
                        subtitle: 'Payable to employees',
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const StatCard(
                        title: 'Currency & Timezone',
                        value: 'BDT (৳)',
                        icon: Icons.schedule,
                        color: AppColors.info,
                        subtitle: 'Asia/Dhaka Standard',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Monthly Payroll Runs Table
            KormoDataTable(
              title: 'Monthly Company Payroll Runs',
              columns: const [
                KormoDataTableColumn(label: 'Period'),
                KormoDataTableColumn(label: 'Total Gross (BDT)'),
                KormoDataTableColumn(label: 'Deductions (BDT)'),
                KormoDataTableColumn(label: 'Net Pay (BDT)'),
                KormoDataTableColumn(label: 'Status'),
                KormoDataTableColumn(label: 'Sign-Off Action'),
              ],
              rows: _sampleRuns.map((run) {
                final isLocked = run['status'] == 'locked';

                return [
                  Text(run['month_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(_formatCurrency(run['gross'])),
                  Text(_formatCurrency(run['deductions']), style: const TextStyle(color: AppColors.danger)),
                  Text(_formatCurrency(run['net']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                  _buildStatusChip(isLocked ? 'Locked & Approved' : 'Draft Review'),
                  if (isDirector && !isLocked)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        minimumSize: const Size(120, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () => _showDirectorApproveModal(run),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Approve & Lock'),
                    )
                  else if (isLocked)
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 16, color: AppColors.muted),
                        SizedBox(width: 4),
                        Text('Locked', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ],
                    )
                  else
                    const Text('Awaiting Director'),
                ];
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Itemized Employee Payslips Table
            KormoDataTable(
              title: 'Individual Payslips & Breakdowns',
              onExportPdf: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating official PDF Payslips with Kormo brand header...')),
                );
              },
              columns: const [
                KormoDataTableColumn(label: 'Employee'),
                KormoDataTableColumn(label: 'Base (BDT)'),
                KormoDataTableColumn(label: 'Allowances'),
                KormoDataTableColumn(label: 'Overtime Pay'),
                KormoDataTableColumn(label: 'Deductions'),
                KormoDataTableColumn(label: 'Net Pay (BDT)'),
                KormoDataTableColumn(label: 'Payslip'),
              ],
              rows: _samplePayslips.map((slip) {
                return [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slip['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(slip['emp_id'], style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                    ],
                  ),
                  Text(_formatCurrency(slip['base'])),
                  Text(_formatCurrency(slip['allowances'])),
                  Text(_formatCurrency(slip['ot']), style: const TextStyle(color: AppColors.orangeText)),
                  Text(_formatCurrency(slip['deductions']), style: const TextStyle(color: AppColors.danger)),
                  Text(_formatCurrency(slip['net']), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryTeal,
                      minimumSize: const Size(90, 36),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Downloading Payslip PDF for ${slip["name"]}...')),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                  ),
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isLocked = status.contains('Locked');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked ? AppColors.successBg : AppColors.warningBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isLocked ? AppColors.success : AppColors.orangeText,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
