class AuditLogModel {
  final String id;
  final String? actorId;
  final String? actorName;
  final String action;
  final String tableName;
  final String? recordId;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String platform;
  final String? ipAddress;
  final DateTime createdAt;

  AuditLogModel({
    required this.id,
    this.actorId,
    this.actorName,
    required this.action,
    required this.tableName,
    this.recordId,
    this.oldData,
    this.newData,
    required this.platform,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] ?? '',
      actorId: json['actor_id'],
      actorName: json['actor'] != null ? json['actor']['full_name'] : null,
      action: json['action'] ?? '',
      tableName: json['table_name'] ?? '',
      recordId: json['record_id'],
      oldData: json['old_data'] != null ? Map<String, dynamic>.from(json['old_data']) : null,
      newData: json['new_data'] != null ? Map<String, dynamic>.from(json['new_data']) : null,
      platform: json['platform'] ?? 'web',
      ipAddress: json['ip_address'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
