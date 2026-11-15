import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../models/audit_model.dart';
import '../supabase_client.dart';

class AdminRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ProfileModel>> getAllEmployees() async {
    try {
      final res = await _client
          .from('profiles')
          .select('*, departments(name), branches(name), shifts(name), manager:manager_id(full_name)')
          .order('created_at', ascending: false);

      return (res as List).map((e) => ProfileModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting employees: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getBranches() async {
    try {
      final res = await _client.from('branches').select().eq('is_active', true).order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getting branches: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDepartments() async {
    try {
      final res = await _client.from('departments').select().eq('is_active', true).order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getting departments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getShifts() async {
    try {
      final res = await _client.from('shifts').select().eq('is_active', true).order('name');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error getting shifts: $e');
      return [];
    }
  }

  // Create User via Edge Function (Enforces can_create & keeps service_role key isolated)
  Future<Map<String, dynamic>> createUser({
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
    final response = await _client.functions.invoke(
      'create-user',
      body: {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': role.name,
        'department_id': departmentId,
        'branch_id': branchId,
        'shift_id': shiftId,
        'designation': designation,
        'employee_id': employeeId,
      },
    );

    if (response.status >= 400) {
      throw Exception(response.data['error'] ?? 'Failed to create employee');
    }

    return Map<String, dynamic>.from(response.data);
  }

  Future<void> toggleUserStatus(String userId, bool isActive, String reason) async {
    final actor = _client.auth.currentUser;
    await _client.from('profiles').update({'is_active': isActive}).eq('id', userId);

    if (actor != null) {
      await _client.from('audit_logs').insert({
        'actor_id': actor.id,
        'action': isActive ? 'REACTIVATE_USER' : 'DEACTIVATE_USER',
        'table_name': 'profiles',
        'record_id': userId,
        'new_data': {'is_active': isActive, 'reason': reason},
        'platform': 'web',
      });
    }
  }

  Future<void> transferDepartment({
    required String userId,
    required String newDepartmentId,
    String? newBranchId,
  }) async {
    final actor = _client.auth.currentUser;
    await _client.from('profiles').update({
      'department_id': newDepartmentId,
      if (newBranchId != null) 'branch_id': newBranchId,
    }).eq('id', userId);

    if (actor != null) {
      await _client.from('audit_logs').insert({
        'actor_id': actor.id,
        'action': 'TRANSFER_DEPARTMENT',
        'table_name': 'profiles',
        'record_id': userId,
        'new_data': {'department_id': newDepartmentId, 'branch_id': newBranchId},
        'platform': 'web',
      });
    }
  }

  Future<List<AuditLogModel>> getAuditLogs() async {
    try {
      final res = await _client
          .from('audit_logs')
          .select('*, actor:profiles!audit_logs_actor_id_fkey(full_name)')
          .order('created_at', ascending: false)
          .limit(100);

      return (res as List).map((e) => AuditLogModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting audit logs: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getSettings() async {
    try {
      final res = await _client.from('settings').select().limit(1).maybeSingle();
      return res != null ? Map<String, dynamic>.from(res) : null;
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return null;
    }
  }
}
