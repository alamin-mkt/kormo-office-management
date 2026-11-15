enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  static TaskPriority fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'low':
        return TaskPriority.low;
      case 'high':
        return TaskPriority.high;
      case 'urgent':
        return TaskPriority.urgent;
      default:
        return TaskPriority.medium;
    }
  }

  String get displayName => name.toUpperCase();
}

enum TaskStatus {
  todo,
  inProgress,
  underReview,
  completed;

  static TaskStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'under_review':
        return TaskStatus.underReview;
      case 'completed':
        return TaskStatus.completed;
      default:
        return TaskStatus.todo;
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To-Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.underReview:
        return 'Under Review';
      case TaskStatus.completed:
        return 'Completed';
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String? assignedTo;
  final String? assigneeName;
  final String createdBy;
  final String? creatorName;
  final String? departmentId;
  final String? departmentName;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.assignedTo,
    this.assigneeName,
    required this.createdBy,
    this.creatorName,
    this.departmentId,
    this.departmentName,
    required this.priority,
    required this.status,
    this.dueDate,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      assignedTo: json['assigned_to'],
      assigneeName: json['assignee'] != null ? json['assignee']['full_name'] : null,
      createdBy: json['created_by'] ?? '',
      creatorName: json['creator'] != null ? json['creator']['full_name'] : null,
      departmentId: json['department_id'],
      departmentName: json['departments'] != null ? json['departments']['name'] : null,
      priority: TaskPriority.fromString(json['priority']),
      status: TaskStatus.fromString(json['status']),
      dueDate: json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
