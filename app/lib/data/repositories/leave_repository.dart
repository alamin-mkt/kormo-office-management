import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/leave_model.dart';
import '../supabase_client.dart';

class LeaveRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<LeaveTypeModel>> getLeaveTypes() async {
    try {
      final res = await _client.from('leave_types').select().eq('is_active', true);
      return (res as List).map((e) => LeaveTypeModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting leave types: $e');
      return [];
    }
  }

  Future<List<LeaveBalanceModel>> getLeaveBalances({String? userId, int? year}) async {
    final targetUser = userId ?? _client.auth.currentUser?.id;
    if (targetUser == null) return [];
    final targetYear = year ?? DateTime.now().year;

    try {
      final res = await _client
          .from('leave_balances')
          .select('*, leave_types(name, code)')
          .eq('user_id', targetUser)
          .eq('year', targetYear);

      return (res as List).map((e) => LeaveBalanceModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting balances: $e');
      return [];
    }
  }

  Future<List<LeaveRequestModel>> getLeaveRequests({
    String? userId,
    LeaveStatus? status,
  }) async {
    try {
      var query = _client.from('leave_requests').select(
        '*, profiles!leave_requests_user_id_fkey(full_name, employee_id), leave_types(name), decided_by_profile:profiles!leave_requests_decided_by_fkey(full_name)'
      );

      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (status != null) {
        query = query.eq('status', status.name);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((e) => LeaveRequestModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting leave requests: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> applyLeave({
    required String leaveTypeId,
    required DateTime startDate,
    required DateTime endDate,
    bool isHalfDay = false,
    String? halfDayType,
    required String reason,
    String? attachmentUrl,
  }) async {
    final res = await _client.rpc('apply_leave', params: {
      'p_leave_type_id': leaveTypeId,
      'p_start_date': startDate.toIso8601String().split('T').first,
      'p_end_date': endDate.toIso8601String().split('T').first,
      'p_is_half_day': isHalfDay,
      'p_half_day_type': halfDayType,
      'p_reason': reason,
      'p_attachment_url': attachmentUrl,
    });
    return Map<String, dynamic>.from(res);
  }

  Future<Map<String, dynamic>> decideLeave({
    required String requestId,
    required LeaveStatus status,
    String? comment,
  }) async {
    final res = await _client.rpc('decide_leave', params: {
      'p_request_id': requestId,
      'p_status': status.name,
      'p_comment': comment,
    });
    return Map<String, dynamic>.from(res);
  }

  Future<void> cancelLeave(String requestId) async {
    await _client.from('leave_requests').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  RealtimeChannel? subscribeToLeaves(void Function() onUpdate) {
    if (!SupabaseConfig.isInitialized) return null;
    final channel = _client.channel('public:leave_requests');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'leave_requests',
      callback: (payload) => onUpdate(),
    ).subscribe();
    return channel;
  }
}
