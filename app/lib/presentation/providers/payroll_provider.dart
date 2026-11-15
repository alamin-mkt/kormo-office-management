import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/payroll_model.dart';
import '../../data/repositories/payroll_repository.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository();
});

class PayrollState {
  final bool isLoading;
  final List<PayrollRunModel> runs;
  final List<PayslipModel> currentPayslips;
  final SalaryStructureModel? personalStructure;
  final String? errorMessage;
  final String? successMessage;

  PayrollState({
    this.isLoading = false,
    this.runs = const [],
    this.currentPayslips = const [],
    this.personalStructure,
    this.errorMessage,
    this.successMessage,
  });

  PayrollState copyWith({
    bool? isLoading,
    List<PayrollRunModel>? runs,
    List<PayslipModel>? currentPayslips,
    SalaryStructureModel? personalStructure,
    String? errorMessage,
    String? successMessage,
  }) {
    return PayrollState(
      isLoading: isLoading ?? this.isLoading,
      runs: runs ?? this.runs,
      currentPayslips: currentPayslips ?? this.currentPayslips,
      personalStructure: personalStructure ?? this.personalStructure,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class PayrollNotifier extends StateNotifier<PayrollState> {
  final PayrollRepository _repo;

  PayrollNotifier(this._repo) : super(PayrollState()) {
    refreshRuns();
  }

  Future<void> refreshRuns() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final runs = await _repo.getPayrollRuns();
      state = state.copyWith(isLoading: false, runs: runs);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadPayslips(String runId) async {
    state = state.copyWith(isLoading: true);
    try {
      final slips = await _repo.getPayslips(payrollRunId: runId);
      state = state.copyWith(isLoading: false, currentPayslips: slips);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> generateDraft(int month, int year, {String? notes}) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.generatePayrollRun(month: month, year: year, notes: notes);
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Draft payroll generated');
      await refreshRuns();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> approveAndLock(String runId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final res = await _repo.approvePayrollRun(runId);
      state = state.copyWith(isLoading: false, successMessage: res['message'] ?? 'Payroll approved and locked');
      await refreshRuns();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }
}

final payrollProvider = StateNotifierProvider<PayrollNotifier, PayrollState>((ref) {
  final repo = ref.watch(payrollRepositoryProvider);
  return PayrollNotifier(repo);
});
