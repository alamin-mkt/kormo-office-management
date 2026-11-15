import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task_model.dart';
import '../supabase_client.dart';

class TaskRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<TaskModel>> getTasks({String? assignedTo, String? departmentId}) async {
    try {
      var query = _client.from('tasks').select(
        '*, assignee:profiles!tasks_assigned_to_fkey(full_name), creator:profiles!tasks_created_by_fkey(full_name), departments(name)'
      );

      if (assignedTo != null) {
        query = query.eq('assigned_to', assignedTo);
      }
      if (departmentId != null) {
        query = query.eq('department_id', departmentId);
      }

      final res = await query.order('created_at', ascending: false);
      return (res as List).map((e) => TaskModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting tasks: $e');
      return [];
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    String? assignedTo,
    String? departmentId,
    required TaskPriority priority,
    DateTime? dueDate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('tasks').insert({
      'title': title,
      'description': description,
      'assigned_to': assignedTo,
      'created_by': user.id,
      'department_id': departmentId,
      'priority': priority.name,
      'status': 'todo',
      'due_date': dueDate?.toIso8601String(),
    });
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    await _client.from('tasks').update({
      'status': status.name,
      'completed_at': status == TaskStatus.completed ? DateTime.now().toIso8601String() : null,
    }).eq('id', taskId);
  }

  RealtimeChannel? subscribeToTasks(void Function() onUpdate) {
    if (!SupabaseConfig.isInitialized) return null;
    final channel = _client.channel('public:tasks');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'tasks',
      callback: (payload) => onUpdate(),
    ).subscribe();
    return channel;
  }
}
