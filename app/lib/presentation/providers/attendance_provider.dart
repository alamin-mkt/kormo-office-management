import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/attendance_model.dart';
import '../../data/repositories/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

class AttendanceState {
  final bool isLoading;
  final AttendanceModel? todayAttendance;
  final List<AttendanceModel> whoIsInNow;
  final List<AttendanceModel> history;
  final String? errorMessage;
  final String? successMessage;

  AttendanceState({
    this.isLoading = false,
    this.todayAttendance,
    this.whoIsInNow = const [],
    this.history = const [],
    this.errorMessage,
    this.successMessage,
  });

  bool get isCheckedIn => todayAttendance?.checkIn != null && todayAttendance?.checkOut == null;
  bool get isCheckedOut => todayAttendance?.checkOut != null;

  AttendanceState copyWith({
    bool? isLoading,
    AttendanceModel? todayAttendance,
    List<AttendanceModel>? whoIsInNow,
    List<AttendanceModel>? history,
    String? errorMessage,
    String? successMessage,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      todayAttendance: todayAttendance ?? this.todayAttendance,
      whoIsInNow: whoIsInNow ?? this.whoIsInNow,
      history: history ?? this.history,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  final AttendanceRepository _repo;

  AttendanceNotifier(this._repo) : super(AttendanceState()) {
    refreshAll();
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    try {
      _repo.subscribeToAttendance(() {
        refreshAll();
      });
    } catch (_) {}
  }

  Future<void> refreshAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final today = await _repo.getTodayAttendance();
      final whoIsIn = await _repo.getWhoIsInOfficeNow();
      final hist = await _repo.getAttendanceHistory();
      state = state.copyWith(
        isLoading: false,
        todayAttendance: today,
        whoIsInNow: whoIsIn,
        history: hist,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> checkIn({
    String? branchId,
    double? latitude,
    double? longitude,
    String? selfieUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.checkIn(
        branchId: branchId,
        latitude: latitude,
        longitude: longitude,
        selfieUrl: selfieUrl,
      );
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Checked in successfully');
      await refreshAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> checkOut({double? latitude, double? longitude}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.checkOut(latitude: latitude, longitude: longitude);
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Checked out successfully');
      await refreshAll();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }
}

final attendanceProvider = StateNotifierProvider<AttendanceNotifier, AttendanceState>((ref) {
  final repo = ref.watch(attendanceRepositoryProvider);
  return AttendanceNotifier(repo);
});
