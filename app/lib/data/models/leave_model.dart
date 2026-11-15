enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static LeaveStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'pending':
        return LeaveStatus.pending;
      case 'approved':
        return LeaveStatus.approved;
      case 'rejected':
        return LeaveStatus.rejected;
      case 'cancelled':
        return LeaveStatus.cancelled;
      default:
        return LeaveStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending Review';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class LeaveTypeModel {
  final String id;
  final String name;
  final String code;
  final double daysAllowed;
  final bool isPaid;
  final bool requiresAttachment;
  final String? description;

  LeaveTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.daysAllowed,
    required this.isPaid,
    this.requiresAttachment = false,
    this.description,
  });

  factory LeaveTypeModel.fromJson(Map<String, dynamic> json) {
    return LeaveTypeModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      daysAllowed: (json['days_allowed'] as num?)?.toDouble() ?? 0.0,
      isPaid: json['is_paid'] ?? true,
      requiresAttachment: json['requires_attachment'] ?? false,
      description: json['description'],
    );
  }
}

class LeaveBalanceModel {
  final String id;
  final String userId;
  final String leaveTypeId;
  final String leaveTypeName;
  final String leaveTypeCode;
  final int year;
  final double allocatedDays;
  final double usedDays;
  final double remainingDays;

  LeaveBalanceModel({
    required this.id,
    required this.userId,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.leaveTypeCode,
    required this.year,
    required this.allocatedDays,
    required this.usedDays,
    required this.remainingDays,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      leaveTypeId: json['leave_type_id'] ?? '',
      leaveTypeName: json['leave_types'] != null ? json['leave_types']['name'] : 'Leave',
      leaveTypeCode: json['leave_types'] != null ? json['leave_types']['code'] : 'LV',
      year: json['year'] ?? DateTime.now().year,
      allocatedDays: (json['allocated_days'] as num?)?.toDouble() ?? 0.0,
      usedDays: (json['used_days'] as num?)?.toDouble() ?? 0.0,
      remainingDays: (json['remaining_days'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeaveRequestModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmployeeId;
  final String leaveTypeId;
  final String? leaveTypeName;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDays;
  final bool isHalfDay;
  final String? halfDayType;
  final String reason;
  final String? attachmentUrl;
  final LeaveStatus status;
  final String? decidedByName;
  final String? decisionComment;
  final DateTime? decidedAt;
  final DateTime createdAt;

  LeaveRequestModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmployeeId,
    required this.leaveTypeId,
    this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    this.isHalfDay = false,
    this.halfDayType,
    required this.reason,
    this.attachmentUrl,
    required this.status,
    this.decidedByName,
    this.decisionComment,
    this.decidedAt,
    required this.createdAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      userEmployeeId: json['profiles'] != null ? json['profiles']['employee_id'] : null,
      leaveTypeId: json['leave_type_id'] ?? '',
      leaveTypeName: json['leave_types'] != null ? json['leave_types']['name'] : null,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      totalDays: (json['total_days'] as num?)?.toDouble() ?? 1.0,
      isHalfDay: json['is_half_day'] ?? false,
      halfDayType: json['half_day_type'],
      reason: json['reason'] ?? '',
      attachmentUrl: json['attachment_url'],
      status: LeaveStatus.fromString(json['status']),
      decidedByName: json['decided_by_profile'] != null ? json['decided_by_profile']['full_name'] : null,
      decisionComment: json['decision_comment'],
      decidedAt: json['decided_at'] != null ? DateTime.tryParse(json['decided_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
