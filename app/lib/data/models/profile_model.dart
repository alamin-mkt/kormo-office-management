enum UserRole {
  director,
  admin,
  hr,
  manager,
  executive,
  employee;

  static UserRole fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'director':
        return UserRole.director;
      case 'admin':
        return UserRole.admin;
      case 'hr':
        return UserRole.hr;
      case 'manager':
        return UserRole.manager;
      case 'executive':
        return UserRole.executive;
      default:
        return UserRole.employee;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.director:
        return 'Director';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.hr:
        return 'HR Manager';
      case UserRole.manager:
        return 'Department Manager';
      case UserRole.executive:
        return 'Executive';
      case UserRole.employee:
        return 'Employee';
    }
  }

  int get hierarchyLevel {
    switch (this) {
      case UserRole.director:
        return 6;
      case UserRole.admin:
        return 5;
      case UserRole.hr:
        return 4;
      case UserRole.manager:
        return 3;
      case UserRole.executive:
        return 2;
      case UserRole.employee:
        return 1;
    }
  }

  bool canCreateRole(UserRole targetRole, {bool isSameDept = true, bool allowExecAdd = false}) {
    if (this == UserRole.director) {
      return targetRole != UserRole.director;
    }
    if (this == UserRole.admin) {
      return targetRole != UserRole.director && targetRole != UserRole.admin;
    }
    if (this == UserRole.hr) {
      return targetRole.hierarchyLevel < UserRole.hr.hierarchyLevel;
    }
    if (this == UserRole.manager) {
      return isSameDept && (targetRole == UserRole.executive || targetRole == UserRole.employee);
    }
    if (this == UserRole.executive) {
      return allowExecAdd && isSameDept && targetRole == UserRole.employee;
    }
    return false;
  }
}

class ProfileModel {
  final String id;
  final String employeeId;
  final String email;
  final String fullName;
  final String? phone;
  final String? photoUrl;
  final UserRole role;
  final String? departmentId;
  final String? departmentName;
  final String? branchId;
  final String? branchName;
  final String? shiftId;
  final String? shiftName;
  final String? managerId;
  final String? managerName;
  final String? designation;
  final String employmentType;
  final DateTime? joiningDate;
  final bool isActive;
  final bool mustChangePassword;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  ProfileModel({
    required this.id,
    required this.employeeId,
    required this.email,
    required this.fullName,
    this.phone,
    this.photoUrl,
    required this.role,
    this.departmentId,
    this.departmentName,
    this.branchId,
    this.branchName,
    this.shiftId,
    this.shiftName,
    this.managerId,
    this.managerName,
    this.designation,
    this.employmentType = 'full_time',
    this.joiningDate,
    this.isActive = true,
    this.mustChangePassword = false,
    this.emergencyContactName,
    this.emergencyContactPhone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] ?? '',
      employeeId: json['employee_id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      photoUrl: json['photo_url'],
      role: UserRole.fromString(json['role']),
      departmentId: json['department_id'],
      departmentName: json['departments'] != null ? json['departments']['name'] : null,
      branchId: json['branch_id'],
      branchName: json['branches'] != null ? json['branches']['name'] : null,
      shiftId: json['shift_id'],
      shiftName: json['shifts'] != null ? json['shifts']['name'] : null,
      managerId: json['manager_id'],
      managerName: json['manager'] != null ? json['manager']['full_name'] : null,
      designation: json['designation'],
      employmentType: json['employment_type'] ?? 'full_time',
      joiningDate: json['joining_date'] != null ? DateTime.tryParse(json['joining_date']) : null,
      isActive: json['is_active'] ?? true,
      mustChangePassword: json['must_change_password'] ?? false,
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'photo_url': photoUrl,
      'role': role.name,
      'department_id': departmentId,
      'branch_id': branchId,
      'shift_id': shiftId,
      'manager_id': managerId,
      'designation': designation,
      'employment_type': employmentType,
      'joining_date': joiningDate?.toIso8601String().split('T').first,
      'is_active': isActive,
      'must_change_password': mustChangePassword,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
    };
  }
}
