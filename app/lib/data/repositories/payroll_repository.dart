import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payroll_model.dart';
import '../supabase_client.dart';

class PayrollRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<PayrollRunModel>> getPayrollRuns() async {
    try {
      final res = await _client
          .from('payroll_runs')
          .select('*, approved_by_profile:profiles!payroll_runs_approved_by_fkey(full_name)')
          .order('year', ascending: false)
          .order('month', ascending: false);

      return (res as List).map((e) => PayrollRunModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting payroll runs: $e');
      return [];
    }
  }

  Future<List<PayslipModel>> getPayslips({String? payrollRunId, String? userId}) async {
    try {
      var query = _client.from('payslips').select(
        '*, profiles(full_name, employee_id, designation)'
      );

      if (payrollRunId != null) {
        query = query.eq('payroll_run_id', payrollRunId);
      }
      if (userId != null) {
        query = query.eq('user_id', userId);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((e) => PayslipModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting payslips: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> generatePayrollRun({
    required int month,
    required int year,
    String? notes,
  }) async {
    final res = await _client.rpc('generate_payroll_run', params: {
      'p_month': month,
      'p_year': year,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> approvePayrollRun(String runId) async {
    final res = await _client.rpc('approve_payroll_run', params: {
      'p_run_id': runId,
    });
    return Map<String, dynamic>.from(res);
  }

  Future<SalaryStructureModel?> getSalaryStructure(String userId) async {
    try {
      final res = await _client
          .from('salary_structures')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (res == null) return null;
      return SalaryStructureModel.fromJson(res);
    } catch (e) {
      debugPrint('Error getting salary structure: $e');
      return null;
    }
  }
}
