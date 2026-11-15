enum AttendanceStatus {
  present,
  late,
  halfDay,
  earlyLeave,
  absent,
  onLeave,
  holiday,
  weekend;

  static AttendanceStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'half_day':
        return AttendanceStatus.halfDay;
      case 'early_leave':
        return AttendanceStatus.earlyLeave;
      case 'absent':
        return AttendanceStatus.absent;
      case 'on_leave':
        return AttendanceStatus.onLeave;
      case 'holiday':
        return AttendanceStatus.holiday;
      case 'weekend':
        return AttendanceStatus.weekend;
      default:
        return AttendanceStatus.absent;
    }
  }

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.earlyLeave:
        return 'Early Leave';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.holiday:
        return 'Holiday';
      case AttendanceStatus.weekend:
        return 'Weekend';
    }
  }
}

class AttendanceModel {
  final String id;
  final String userId;
  final String? userName;
  final String? userEmployeeId;
  final String? userPhotoUrl;
  final String? branchId;
  final String? branchName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AttendanceStatus status;
  final double? checkInLat;
  final double? checkInLng;
  final String? checkInSelfieUrl;
  final int workMinutes;
  final int breakMinutes;
  final int overtimeMinutes;
  final bool isOfflineSync;
  final String? notes;

  AttendanceModel({
    required this.id,
    required this.userId,
    this.userName,
    this.userEmployeeId,
    this.userPhotoUrl,
    this.branchId,
    this.branchName,
    required this.date,
    this.checkIn,
    this.checkOut,
    required this.status,
    this.checkInLat,
    this.checkInLng,
    this.checkInSelfieUrl,
    this.workMinutes = 0,
    this.breakMinutes = 0,
    this.overtimeMinutes = 0,
    this.isOfflineSync = false,
    this.notes,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      userEmployeeId: json['profiles'] != null ? json['profiles']['employee_id'] : null,
      userPhotoUrl: json['profiles'] != null ? json['profiles']['photo_url'] : null,
      branchId: json['branch_id'],
      branchName: json['branches'] != null ? json['branches']['name'] : null,
      date: DateTime.parse(json['date']),
      checkIn: json['check_in'] != null ? DateTime.parse(json['check_in']) : null,
      checkOut: json['check_out'] != null ? DateTime.parse(json['check_out']) : null,
      status: AttendanceStatus.fromString(json['status']),
      checkInLat: json['check_in_lat'] != null ? (json['check_in_lat'] as num).toDouble() : null,
      checkInLng: json['check_in_lng'] != null ? (json['check_in_lng'] as num).toDouble() : null,
      checkInSelfieUrl: json['check_in_selfie_url'],
      workMinutes: json['work_minutes'] ?? 0,
      breakMinutes: json['break_minutes'] ?? 0,
      overtimeMinutes: json['overtime_minutes'] ?? 0,
      isOfflineSync: json['is_offline_sync'] ?? false,
      notes: json['notes'],
    );
  }

  String get workHoursDisplay {
    final hours = workMinutes ~/ 60;
    final minutes = workMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  String get overtimeDisplay {
    if (overtimeMinutes <= 0) return '0h';
    final hours = overtimeMinutes ~/ 60;
    final minutes = overtimeMinutes % 60;
    return '${hours}h ${minutes}m';
  }
}
