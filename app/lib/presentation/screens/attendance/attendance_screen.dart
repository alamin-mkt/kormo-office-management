import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/attendance_provider.dart';
import '../../widgets/kormo_data_table.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handlePunch() async {
    final attendanceState = ref.read(attendanceProvider);
    if (!attendanceState.isCheckedIn) {
      // Mock / default HQ coordinates for web/desktop check-in
      await ref.read(attendanceProvider.notifier).checkIn(
            latitude: 23.7925,
            longitude: 90.4078,
          );
    } else {
      await ref.read(attendanceProvider.notifier).checkOut(
            latitude: 23.7925,
            longitude: 90.4078,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceState = ref.watch(attendanceProvider);
    final today = attendanceState.todayAttendance;
    final isCheckedIn = attendanceState.isCheckedIn;
    final isCheckedOut = attendanceState.isCheckedOut;

    final formattedTime = DateFormat('hh:mm:ss a').format(_currentTime);
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(_currentTime);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            const Text(
              'Attendance & Time Tracking',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
            ),
            const SizedBox(height: 4),
            const Text(
              'Server-time validated check-in with GPS geofence and overtime calculations',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (attendanceState.errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Text(attendanceState.errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),

            if (attendanceState.successMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: Text(attendanceState.successMessage!, style: const TextStyle(color: AppColors.success, fontSize: 13)),
              ),

            // Today's Punch Action Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  // Live Clock Display
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.tealBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Asia/Dhaka Server Time',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on, size: 14, color: AppColors.success),
                            const Text('HQ Banani Geofence: Active', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formattedTime,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 14, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),

                  // Today Summary Badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          _buildPunchBadge('Check In', today?.checkIn != null ? DateFormat('hh:mm a').format(today!.checkIn!) : '--:--'),
                          const SizedBox(width: 12),
                          _buildPunchBadge('Check Out', today?.checkOut != null ? DateFormat('hh:mm a').format(today!.checkOut!) : '--:--'),
                          const SizedBox(width: 12),
                          _buildPunchBadge('Work Hours', today?.workHoursDisplay ?? '0h 0m'),
                          const SizedBox(width: 12),
                          _buildPunchBadge('Overtime', today?.overtimeDisplay ?? '0h'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Punch Button (Orange for check-in)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCheckedIn ? AppColors.danger : AppColors.accentOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isCheckedOut ? null : _handlePunch,
                        icon: Icon(isCheckedIn ? Icons.logout : Icons.fingerprint, size: 20),
                        label: Text(
                          isCheckedOut
                              ? 'Checked Out Today'
                              : isCheckedIn
                                  ? 'Check Out (End Workday)'
                                  : 'Check In (Orange Action)',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Attendance Logs Table (KormoDataTable)
            KormoDataTable(
              title: 'Attendance History & Punch Records',
              columns: const [
                KormoDataTableColumn(label: 'Date'),
                KormoDataTableColumn(label: 'Check In'),
                KormoDataTableColumn(label: 'Check Out'),
                KormoDataTableColumn(label: 'Status'),
                KormoDataTableColumn(label: 'Work Duration'),
                KormoDataTableColumn(label: 'Overtime'),
                KormoDataTableColumn(label: 'Office Branch'),
              ],
              rows: attendanceState.history.map((record) {
                final dateStr = DateFormat('dd MMM yyyy').format(record.date);
                final checkInStr = record.checkIn != null ? DateFormat('hh:mm a').format(record.checkIn!) : '--';
                final checkOutStr = record.checkOut != null ? DateFormat('hh:mm a').format(record.checkOut!) : '--';

                return [
                  Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(checkInStr),
                  Text(checkOutStr),
                  _buildStatusChip(record.status.displayName),
                  Text(record.workHoursDisplay),
                  Text(record.overtimeDisplay, style: TextStyle(color: record.overtimeMinutes > 0 ? AppColors.orangeText : AppColors.muted)),
                  Text(record.branchName ?? 'HQ Banani'),
                ];
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPunchBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = AppColors.successBg;
    Color fg = AppColors.success;

    if (status == 'Late') {
      bg = AppColors.warningBg;
      fg = AppColors.orangeText;
    } else if (status == 'Absent') {
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
