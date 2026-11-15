import 'package:intl/intl.dart';

enum AppLanguage { en, bn }

class AppLocale {
  final AppLanguage language;
  AppLocale(this.language);

  bool get isBengali => language == AppLanguage.bn;

  // Currency Formatter (BDT ৳)
  String formatCurrency(num amount) {
    final formatter = NumberFormat("#,##,##0.00", "en_US");
    final formatted = formatter.format(amount);
    return isBengali ? "৳ $formatted" : "BDT $formatted";
  }

  // Date Formatter (Asia/Dhaka)
  String formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  String formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }

  // Key-value localization dictionary
  String t(String key) {
    final dict = isBengali ? _bn : _en;
    return dict[key] ?? key;
  }

  static const Map<String, String> _en = {
    'app_name': 'Kormo',
    'tagline': 'Enterprise Office Management System',
    'login': 'Sign In',
    'logout': 'Sign Out',
    'email': 'Work Email',
    'password': 'Password',
    'dashboard': 'Dashboard',
    'attendance': 'Attendance',
    'check_in': 'Check In',
    'check_out': 'Check Out',
    'leave': 'Leave Management',
    'apply_leave': 'Apply Leave',
    'users': 'Employees',
    'add_user': 'Add User',
    'tasks': 'Tasks',
    'notices': 'Notices',
    'payroll': 'Payroll',
    'reports': 'Reports',
    'settings': 'Settings',
    'who_is_in': 'Who is in office now',
    'present': 'Present',
    'late': 'Late',
    'absent': 'Absent',
    'on_leave': 'On Leave',
    'half_day': 'Half Day',
    'overtime': 'Overtime',
    'total_employees': 'Total Staff',
    'pending_approvals': 'Pending Approvals',
    'role_director': 'Director',
    'role_admin': 'Administrator',
    'role_hr': 'HR Manager',
    'role_manager': 'Manager',
    'role_executive': 'Executive',
    'role_employee': 'Employee',
    'language_en': 'English',
    'language_bn': 'বাংলা',
  };

  static const Map<String, String> _bn = {
    'app_name': 'কর্ম (Kormo)',
    'tagline': 'এন্টারপ্রাইজ অফিস ম্যানেজমেন্ট সিস্টেম',
    'login': 'লগইন করুন',
    'logout': 'লগআউট',
    'email': 'অফিস ইমেইল',
    'password': 'পাসওয়ার্ড',
    'dashboard': 'ড্যাশবোর্ড',
    'attendance': 'উপস্থিতি',
    'check_in': 'চেক-ইন',
    'check_out': 'চেক-আউট',
    'leave': 'ছুটি ব্যবস্থাপনা',
    'apply_leave': 'ছুটির আবেদন',
    'users': 'কর্মকর্তা ও কর্মচারী',
    'add_user': 'নতুন কর্মী যোগ',
    'tasks': 'টাস্ক ও কার্যক্রম',
    'notices': 'নোটিশ বোর্ড',
    'payroll': 'বেতন ও পে-রোল',
    'reports': 'রিপোর্ট ও নিরীক্ষা',
    'settings': 'সেটিংস',
    'who_is_in': 'বর্তমানে অফিসে উপস্থিত',
    'present': 'উপস্থিত',
    'late': 'দেরি',
    'absent': 'অনুপস্থিত',
    'on_leave': 'ছুটিতে',
    'half_day': 'হাফ-ডে',
    'overtime': 'ওভারটাইম',
    'total_employees': 'মোট কর্মী',
    'pending_approvals': 'অপেক্ষমান অনুমোদন',
    'role_director': 'পরিচালক (Director)',
    'role_admin': 'প্রশাসক (Admin)',
    'role_hr': 'এইচআর ম্যানেজার (HR)',
    'role_manager': 'বিভাগীয় প্রধান (Manager)',
    'role_executive': 'এক্সিকিউটিভ',
    'role_employee': 'কর্মচারী',
    'language_en': 'English',
    'language_bn': 'বাংলা',
  };
}
