import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/audit_model.dart';
import '../../data/repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository();
});

class AdminState {
  final bool isLoading;
  final List<ProfileModel> employees;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> departments;
  final List<Map<String, dynamic>> shifts;
  final List<AuditLogModel> auditLogs;
  final Map<String, dynamic>? settings;
  final String? errorMessage;
  final String? successMessage;

  AdminState({
    this.isLoading = false,
    this.employees = const [],
    this.branches = const [],
    this.departments = const [],
    this.shifts = const [],
    this.auditLogs = const [],
    this.settings,
    this.errorMessage,
    this.successMessage,
  });

  AdminState copyWith({
    bool? isLoading,
    List<ProfileModel>? employees,
    List<Map<String, dynamic>>? branches,
    List<Map<String, dynamic>>? departments,
    List<Map<String, dynamic>>? shifts,
    List<AuditLogModel>? auditLogs,
    Map<String, dynamic>? settings,
    String? errorMessage,
    String? successMessage,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      employees: employees ?? this.employees,
      branches: branches ?? this.branches,
      departments: departments ?? this.departments,
      shifts: shifts ?? this.shifts,
      auditLogs: auditLogs ?? this.auditLogs,
      settings: settings ?? this.settings,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final AdminRepository _repo;

  AdminNotifier(this._repo) : super(AdminState()) {
    refreshAll();
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final emps = await _repo.getAllEmployees();
      final branches = await _repo.getBranches();
      final depts = await _repo.getDepartments();
      final shifts = await _repo.getShifts();
      final logs = await _repo.getAuditLogs();
      final settings = await _repo.getSettings();

      state = state.copyWith(
        isLoading: false,
        employees: emps,
        branches: branches,
        departments: depts,
        shifts: shifts,
        auditLogs: logs,
        settings: settings,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createUser({
    required String email,
    String? password,
    required String fullName,
    String? phone,
    required UserRole role,
    String? departmentId,
    String? branchId,
    String? shiftId,
    String? designation,
    String? employeeId,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.createUser(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
        departmentId: departmentId,
        branchId: branchId,
        shiftId: shiftId,
        designation: designation,
        employeeId: employeeId,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: res['message'] ?? 'Employee created successfully',
      );
      await refreshAll();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> toggleUserStatus(String userId, bool isActive, String reason) async {
    try {
      await _repo.toggleUserStatus(userId, isActive, reason);
      await refreshAll();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> transferDepartment({
    required String userId,
    required String newDepartmentId,
    String? newBranchId,
  }) async {
    try {
      await _repo.transferDepartment(
        userId: userId,
        newDepartmentId: newDepartmentId,
        newBranchId: newBranchId,
      );
      await refreshAll();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return AdminNotifier(repo);
});
