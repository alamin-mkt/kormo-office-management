import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/profile_model.dart';
import '../../data/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthState {
  final bool isLoading;
  final ProfileModel? profile;
  final String? errorMessage;

  AuthState({
    this.isLoading = false,
    this.profile,
    this.errorMessage,
  });

  bool get isAuthenticated => profile != null;
  UserRole get role => profile?.role ?? UserRole.employee;

  AuthState copyWith({
    bool? isLoading,
    ProfileModel? profile,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(AuthState(isLoading: true)) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _repo.fetchCurrentProfile();
      state = state.copyWith(isLoading: false, profile: profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _repo.signInWithEmailPassword(email: email, password: password);
      if (response.user != null) {
        await loadProfile();
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Authentication failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> adminSignUp({
    required String email,
    required String password,
    required String fullName,
    String? companyName,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _repo.signUpAdmin(
        email: email,
        password: password,
        fullName: fullName,
        companyName: companyName,
        phone: phone,
      );
      if (response.user != null) {
        if (response.session != null) {
          await loadProfile();
        }
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Admin registration failed');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = AuthState();
  }

  // Developer switch for quick role testing / verification
  void setMockRoleProfile(UserRole role) {
    state = state.copyWith(
      profile: ProfileModel(
        id: 'mock-user-id',
        employeeId: 'KORMO-${role.name.toUpperCase()}',
        email: '${role.name}@kormo.com',
        fullName: '${role.displayName} User',
        role: role,
        designation: '${role.displayName} Title',
        departmentName: 'Engineering',
        branchName: 'Dhaka HQ',
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
