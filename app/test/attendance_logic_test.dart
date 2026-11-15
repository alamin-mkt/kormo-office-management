import 'package:flutter_test/flutter_test.dart';
import 'package:kormo_app/data/models/attendance_model.dart';

void main() {
  group('ATT-06 & ATT-08 Attendance & Overtime Logic Unit Tests', () {
    test('AttendanceModel work hours and overtime formatting', () {
      final model = AttendanceModel(
        id: 'att_01',
        userId: 'user_01',
        date: DateTime(2026, 11, 15),
        status: AttendanceStatus.present,
        workMinutes: 510, // 8h 30m
        overtimeMinutes: 30, // 30m
      );

      expect(model.workHoursDisplay, '8h 30m');
      expect(model.overtimeDisplay, '0h 30m');
    });

    test('Zero overtime displays 0h', () {
      final model = AttendanceModel(
        id: 'att_02',
        userId: 'user_02',
        date: DateTime(2026, 11, 15),
        status: AttendanceStatus.present,
        workMinutes: 480, // exactly 8h
        overtimeMinutes: 0,
      );

      expect(model.workHoursDisplay, '8h 0m');
      expect(model.overtimeDisplay, '0h');
    });

    test('All 8 attendance status enum values map correctly', () {
      expect(AttendanceStatus.fromString('present'), AttendanceStatus.present);
      expect(AttendanceStatus.fromString('late'), AttendanceStatus.late);
      expect(AttendanceStatus.fromString('half_day'), AttendanceStatus.halfDay);
      expect(AttendanceStatus.fromString('early_leave'), AttendanceStatus.earlyLeave);
      expect(AttendanceStatus.fromString('absent'), AttendanceStatus.absent);
      expect(AttendanceStatus.fromString('on_leave'), AttendanceStatus.onLeave);
      expect(AttendanceStatus.fromString('holiday'), AttendanceStatus.holiday);
      expect(AttendanceStatus.fromString('weekend'), AttendanceStatus.weekend);
    });
  });
}
