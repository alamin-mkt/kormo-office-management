import 'package:flutter_test/flutter_test.dart';
import 'package:kormo_app/data/models/leave_model.dart';

void main() {
  group('LEAVE-01 & LEAVE-04 Leave Balance & Status Logic Unit Tests', () {
    test('LeaveBalanceModel remaining days calculation', () {
      final balance = LeaveBalanceModel(
        id: 'bal_01',
        userId: 'user_01',
        leaveTypeId: 'lt_annual',
        leaveTypeName: 'Annual Leave',
        leaveTypeCode: 'AL',
        year: 2026,
        allocatedDays: 14.0,
        usedDays: 4.5,
        remainingDays: 9.5,
      );

      expect(balance.allocatedDays - balance.usedDays, balance.remainingDays);
      expect(balance.remainingDays, 9.5);
    });

    test('LeaveStatus enum states map accurately', () {
      expect(LeaveStatus.fromString('pending'), LeaveStatus.pending);
      expect(LeaveStatus.fromString('approved'), LeaveStatus.approved);
      expect(LeaveStatus.fromString('rejected'), LeaveStatus.rejected);
      expect(LeaveStatus.fromString('cancelled'), LeaveStatus.cancelled);
    });
  });
}
