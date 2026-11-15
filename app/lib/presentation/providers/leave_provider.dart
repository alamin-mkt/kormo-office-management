import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/leave_model.dart';
import '../../data/repositories/leave_repository.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository();
});

class LeaveState {
  final bool isLoading;
  final List<LeaveTypeModel> leaveTypes;
  final List<LeaveBalanceModel> balances;
  final List<LeaveRequestModel> requests;
  final String? errorMessage;
  final String? successMessage;

  LeaveState({
    this.isLoading = false,
    this.leaveTypes = const [],
    this.balances = const [],
    this.requests = const [],
    this.errorMessage,
    this.successMessage,
  });

  LeaveState copyWith({
    bool? isLoading,
    List<LeaveTypeModel>? leaveTypes,
    List<LeaveBalanceModel>? balances,
    List<LeaveRequestModel>? requests,
    String? errorMessage,
    String? successMessage,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      leaveTypes: leaveTypes ?? this.leaveTypes,
      balances: balances ?? this.balances,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class LeaveNotifier extends StateNotifier<LeaveState> {
  final LeaveRepository _repo;

  LeaveNotifier(this._repo) : super(LeaveState()) {
    refreshAll();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    try {
      _repo.subscribeToLeaves(() => refreshAll());
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final types = await _repo.getLeaveTypes();
      final balances = await _repo.getLeaveBalances();
      final reqs = await _repo.getLeaveRequests();
      state = state.copyWith(
        isLoading: false,
        leaveTypes: types,
        balances: balances,
        requests: reqs,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> applyLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    bool isHalfDay = false,
    String? halfDayType,
    required String reason,
    String? attachmentUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.applyLeave(
        leaveTypeId: leaveTypeId,
        startDate: startDate,
        endDate: endDate,
        isHalfDay: isHalfDay,
        halfDayType: halfDayType,
        reason: reason,
        attachmentUrl: attachmentUrl,
      );
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Leave applied successfully');
      await refreshAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> decideLeave({
    required String requestId,
    required LeaveStatus status,
    String? comment,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.decideLeave(requestId: requestId, status: status, comment: comment);
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Decision recorded');
      await refreshAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> cancelLeave(String requestId) async {
    try {
      await _repo.cancelLeave(requestId);
      await refreshAll();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final leaveProvider = StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return LeaveNotifier(repo);
});
