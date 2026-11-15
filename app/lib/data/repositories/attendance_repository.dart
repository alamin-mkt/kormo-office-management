import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';
import '../supabase_client.dart';

class AttendanceRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  // Server-Time Check-In RPC
  Future<Map<String, dynamic>> checkIn({
    String? branchId,
    double? latitude,
    double? longitude,
    String? selfieUrl,
    String? ipAddress,
    String? wifiBssid,
  }) async {
    final response = await _client.rpc('check_in', params: {
      'p_branch_id': branchId,
      'p_lat': latitude,
      'p_lng': longitude,
      'p_selfie_url': selfieUrl,
      'p_ip': ipAddress,
      'p_wifi': wifiBssid,
    });
    return Map<String, dynamic>.from(response);
  }

  // Server-Time Check-Out RPC
  Future<Map<String, dynamic>> checkOut({
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc('check_out', params: {
      'p_lat': latitude,
      'p_lng': longitude,
    });
    return Map<String, dynamic>.from(response);
  }

  // Fetch Current User's Today Attendance
  Future<AttendanceModel?> getTodayAttendance() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final today = DateTime.now().toIso8601String().split('T').first;

    try {
      final res = await _client
          .from('attendance')
          .select('*, profiles(full_name, employee_id, photo_url), branches(name)')
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      if (res == null) return null;
      return AttendanceModel.fromJson(res);
    } catch (e) {
      debugPrint('Error getting today attendance: $e');
      return null;
    }
  }

  // Fetch Attendance History (scoped by RLS)
  Future<List<AttendanceModel>> getAttendanceHistory({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _client
          .from('attendance')
          .select('*, profiles(full_name, employee_id, photo_url), branches(name)');

      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (startDate != null) {
        query = query.gte('date', startDate.toIso8601String().split('T').first);
      }
      if (endDate != null) {
        query = query.lte('date', endDate.toIso8601String().split('T').first);
      }

      final res = await query.order('date', ascending: false).limit(100);
      return (res as List).map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetching attendance history: $e');
      return [];
    }
  }

  // Live "Who is in office now" board (Checked in today, not yet checked out)
  Future<List<AttendanceModel>> getWhoIsInOfficeNow() async {
    final today = DateTime.now().toIso8601String().split('T').first;

    try {
      final res = await _client
          .from('attendance')
          .select('*, profiles(full_name, employee_id, photo_url), branches(name)')
          .eq('date', today)
          .not('check_in', 'is', null)
          .isFilter('check_out', null)
          .order('check_in', ascending: false);

      return (res as List).map((e) => AttendanceModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting active attendees: $e');
      return [];
    }
  }

  // Realtime Attendance Stream (One backend, instant sync on web & mobile)
  RealtimeChannel? subscribeToAttendance(void Function() onUpdate) {
    if (!SupabaseConfig.isInitialized) return null;
    final channel = _client.channel('public:attendance');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'attendance',
      callback: (payload) {
        onUpdate();
      },
    ).subscribe();
    return channel;
  }
}
