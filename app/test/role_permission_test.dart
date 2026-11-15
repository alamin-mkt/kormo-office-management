import 'package:flutter_test/flutter_test.dart';
import 'package:kormo_app/data/models/profile_model.dart';

void main() {
  group('ROLE-01 & ROLE-03 Hierarchy & Permission Unit Tests', () {
    test('Hierarchy order is director > admin > hr > manager > executive > employee', () {
      expect(UserRole.director.hierarchyLevel, 6);
      expect(UserRole.admin.hierarchyLevel, 5);
      expect(UserRole.hr.hierarchyLevel, 4);
      expect(UserRole.manager.hierarchyLevel, 3);
      expect(UserRole.executive.hierarchyLevel, 2);
      expect(UserRole.employee.hierarchyLevel, 1);

      expect(UserRole.director.hierarchyLevel > UserRole.admin.hierarchyLevel, isTrue);
      expect(UserRole.admin.hierarchyLevel > UserRole.hr.hierarchyLevel, isTrue);
      expect(UserRole.hr.hierarchyLevel > UserRole.manager.hierarchyLevel, isTrue);
      expect(UserRole.manager.hierarchyLevel > UserRole.executive.hierarchyLevel, isTrue);
      expect(UserRole.executive.hierarchyLevel > UserRole.employee.hierarchyLevel, isTrue);
    });

    test('Director can create all roles below Director (any department)', () {
      expect(UserRole.director.canCreateRole(UserRole.director), isFalse); // Cannot create Director
      expect(UserRole.director.canCreateRole(UserRole.admin), isTrue);
      expect(UserRole.director.canCreateRole(UserRole.hr), isTrue);
      expect(UserRole.director.canCreateRole(UserRole.manager), isTrue);
      expect(UserRole.director.canCreateRole(UserRole.executive), isTrue);
      expect(UserRole.director.canCreateRole(UserRole.employee), isTrue);
    });

    test('Admin can create HR, Manager, Executive, Employee (cannot create Director or Admin)', () {
      expect(UserRole.admin.canCreateRole(UserRole.director), isFalse);
      expect(UserRole.admin.canCreateRole(UserRole.admin), isFalse);
      expect(UserRole.admin.canCreateRole(UserRole.hr), isTrue);
      expect(UserRole.admin.canCreateRole(UserRole.manager), isTrue);
      expect(UserRole.admin.canCreateRole(UserRole.executive), isTrue);
      expect(UserRole.admin.canCreateRole(UserRole.employee), isTrue);
    });

    test('HR can create Manager, Executive, Employee (cannot create Director, Admin, or HR)', () {
      expect(UserRole.hr.canCreateRole(UserRole.director), isFalse);
      expect(UserRole.hr.canCreateRole(UserRole.admin), isFalse);
      expect(UserRole.hr.canCreateRole(UserRole.hr), isFalse);
      expect(UserRole.hr.canCreateRole(UserRole.manager), isTrue);
      expect(UserRole.hr.canCreateRole(UserRole.executive), isTrue);
      expect(UserRole.hr.canCreateRole(UserRole.employee), isTrue);
    });

    test('Manager can only create Executive and Employee in OWN department', () {
      // In same department
      expect(UserRole.manager.canCreateRole(UserRole.director, isSameDept: true), isFalse);
      expect(UserRole.manager.canCreateRole(UserRole.manager, isSameDept: true), isFalse);
      expect(UserRole.manager.canCreateRole(UserRole.executive, isSameDept: true), isTrue);
      expect(UserRole.manager.canCreateRole(UserRole.employee, isSameDept: true), isTrue);

      // In different department
      expect(UserRole.manager.canCreateRole(UserRole.executive, isSameDept: false), isFalse);
      expect(UserRole.manager.canCreateRole(UserRole.employee, isSameDept: false), isFalse);
    });

    test('Executive can only create Employee in OWN dept IF allow_executive_add_user is ON', () {
      // When toggle is OFF (default)
      expect(UserRole.executive.canCreateRole(UserRole.employee, isSameDept: true, allowExecAdd: false), isFalse);

      // When toggle is ON
      expect(UserRole.executive.canCreateRole(UserRole.employee, isSameDept: true, allowExecAdd: true), isTrue);
      expect(UserRole.executive.canCreateRole(UserRole.employee, isSameDept: false, allowExecAdd: true), isFalse); // Other dept rejected
      expect(UserRole.executive.canCreateRole(UserRole.executive, isSameDept: true, allowExecAdd: true), isFalse); // Cannot self-promote
    });

    test('Employee cannot create any role', () {
      for (final target in UserRole.values) {
        expect(UserRole.employee.canCreateRole(target, isSameDept: true, allowExecAdd: true), isFalse);
      }
    });
  });
}
