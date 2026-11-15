class SalaryStructureModel {
  final String id;
  final String userId;
  final double baseSalary;
  final double houseRent;
  final double medicalAllowance;
  final double conveyanceAllowance;
  final double otherAllowances;
  final double taxDeduction;
  final double otherDeductions;
  final double grossSalary;
  final double netSalary;
  final DateTime effectiveFrom;

  SalaryStructureModel({
    required this.id,
    required this.userId,
    required this.baseSalary,
    required this.houseRent,
    required this.medicalAllowance,
    required this.conveyanceAllowance,
    required this.otherAllowances,
    required this.taxDeduction,
    required this.otherDeductions,
    required this.grossSalary,
    required this.netSalary,
    required this.effectiveFrom,
  });

  factory SalaryStructureModel.fromJson(Map<String, dynamic> json) {
    return SalaryStructureModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
      houseRent: (json['house_rent'] as num?)?.toDouble() ?? 0.0,
      medicalAllowance: (json['medical_allowance'] as num?)?.toDouble() ?? 0.0,
      conveyanceAllowance: (json['conveyance_allowance'] as num?)?.toDouble() ?? 0.0,
      otherAllowances: (json['other_allowances'] as num?)?.toDouble() ?? 0.0,
      taxDeduction: (json['tax_deduction'] as num?)?.toDouble() ?? 0.0,
      otherDeductions: (json['other_deductions'] as num?)?.toDouble() ?? 0.0,
      grossSalary: (json['gross_salary'] as num?)?.toDouble() ?? 0.0,
      netSalary: (json['net_salary'] as num?)?.toDouble() ?? 0.0,
      effectiveFrom: DateTime.parse(json['effective_from']),
    );
  }
}

class PayrollRunModel {
  final String id;
  final int month;
  final int year;
  final String status; // 'draft', 'approved', 'locked', 'paid'
  final double totalGross;
  final double totalDeductions;
  final double totalNet;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? notes;
  final DateTime createdAt;

  PayrollRunModel({
    required this.id,
    required this.month,
    required this.year,
    required this.status,
    required this.totalGross,
    required this.totalDeductions,
    required this.totalNet,
    this.approvedByName,
    this.approvedAt,
    this.notes,
    required this.createdAt,
  });

  factory PayrollRunModel.fromJson(Map<String, dynamic> json) {
    return PayrollRunModel(
      id: json['id'] ?? '',
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
      status: json['status'] ?? 'draft',
      totalGross: (json['total_gross'] as num?)?.toDouble() ?? 0.0,
      totalDeductions: (json['total_deductions'] as num?)?.toDouble() ?? 0.0,
      totalNet: (json['total_net'] as num?)?.toDouble() ?? 0.0,
      approvedByName: json['approved_by_profile'] != null ? json['approved_by_profile']['full_name'] : null,
      approvedAt: json['approved_at'] != null ? DateTime.tryParse(json['approved_at']) : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isLocked => status == 'locked' || status == 'paid';
}

class PayslipModel {
  final String id;
  final String payrollRunId;
  final String userId;
  final String? userName;
  final String? userEmployeeId;
  final String? userDesignation;
  final double baseSalary;
  final double allowances;
  final double overtimePay;
  final double unpaidLeaveDeductions;
  final double lateDeductions;
  final double taxDeductions;
  final double otherDeductions;
  final double netPay;
  final String paymentStatus;
  final String? pdfUrl;
  final DateTime createdAt;

  PayslipModel({
    required this.id,
    required this.payrollRunId,
    required this.userId,
    this.userName,
    this.userEmployeeId,
    this.userDesignation,
    required this.baseSalary,
    required this.allowances,
    required this.overtimePay,
    required this.unpaidLeaveDeductions,
    required this.lateDeductions,
    required this.taxDeductions,
    required this.otherDeductions,
    required this.netPay,
    required this.paymentStatus,
    this.pdfUrl,
    required this.createdAt,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    return PayslipModel(
      id: json['id'] ?? '',
      payrollRunId: json['payroll_run_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['profiles'] != null ? json['profiles']['full_name'] : null,
      userEmployeeId: json['profiles'] != null ? json['profiles']['employee_id'] : null,
      userDesignation: json['profiles'] != null ? json['profiles']['designation'] : null,
      baseSalary: (json['base_salary'] as num?)?.toDouble() ?? 0.0,
      allowances: (json['allowances'] as num?)?.toDouble() ?? 0.0,
      overtimePay: (json['overtime_pay'] as num?)?.toDouble() ?? 0.0,
      unpaidLeaveDeductions: (json['unpaid_leave_deductions'] as num?)?.toDouble() ?? 0.0,
      lateDeductions: (json['late_deductions'] as num?)?.toDouble() ?? 0.0,
      taxDeductions: (json['tax_deductions'] as num?)?.toDouble() ?? 0.0,
      otherDeductions: (json['other_deductions'] as num?)?.toDouble() ?? 0.0,
      netPay: (json['net_pay'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'unpaid',
      pdfUrl: json['pdf_url'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
