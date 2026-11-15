import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notice_model.dart';
import '../supabase_client.dart';

class NoticeRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<NoticeModel>> getNotices() async {
    final currentUserId = _client.auth.currentUser?.id;

    try {
      final res = await _client
          .from('notices')
          .select('*, profiles(full_name), notice_reads(user_id)')
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);

      return (res as List)
          .map((e) => NoticeModel.fromJson(e, currentUserId: currentUserId))
          .toList();
    } catch (e) {
      debugPrint('Error getting notices: $e');
      return [];
    }
  }

  Future<void> publishNotice({
    required String title,
    required String content,
    String targetType = 'all',
    String? targetBranchId,
    String? targetDepartmentId,
    bool isPinned = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('notices').insert({
      'title': title,
      'content': content,
      'published_by': user.id,
      'target_type': targetType,
      'target_branch_id': targetBranchId,
      'target_department_id': targetDepartmentId,
      'is_pinned': isPinned,
    });
  }

  Future<void> markNoticeAsRead(String noticeId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('notice_reads').upsert({
        'notice_id': noticeId,
        'user_id': user.id,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error marking notice read: $e');
    }
  }

  RealtimeChannel? subscribeToNotices(void Function() onUpdate) {
    if (!SupabaseConfig.isInitialized) return null;
    final channel = _client.channel('public:notices');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'notices',
      callback: (payload) => onUpdate(),
    ).subscribe();
    return channel;
  }
}
