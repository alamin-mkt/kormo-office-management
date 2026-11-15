class NoticeModel {
  final String id;
  final String title;
  final String content;
  final String publishedBy;
  final String? publisherName;
  final String targetType; // 'all', 'branch', 'department'
  final String? targetBranchId;
  final String? targetDepartmentId;
  final bool isPinned;
  final DateTime createdAt;
  final bool isRead;

  NoticeModel({
    required this.id,
    required this.title,
    required this.content,
    required this.publishedBy,
    this.publisherName,
    this.targetType = 'all',
    this.targetBranchId,
    this.targetDepartmentId,
    this.isPinned = false,
    required this.createdAt,
    this.isRead = false,
  });

  factory NoticeModel.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    bool read = false;
    if (json['notice_reads'] != null && json['notice_reads'] is List) {
      final reads = json['notice_reads'] as List;
      if (currentUserId != null) {
        read = reads.any((r) => r['user_id'] == currentUserId);
      }
    }

    return NoticeModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      publishedBy: json['published_by'] ?? '',
      publisherName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      targetType: json['target_type'] ?? 'all',
      targetBranchId: json['target_branch_id'],
      targetDepartmentId: json['target_department_id'],
      isPinned: json['is_pinned'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      isRead: read,
    );
  }
}
