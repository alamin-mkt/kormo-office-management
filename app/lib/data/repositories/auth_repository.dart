import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile_model.dart';
import '../supabase_client.dart';

class AuthRepository {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentAuthUser => _client.auth.currentUser;
  bool get isAuthenticated => currentAuthUser != null;

  Future<ProfileModel?> fetchCurrentProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;

    try {
      final res = await _client
          .from('profiles')
          .select('*, departments(name), branches(name), shifts(name), manager:manager_id(full_name)')
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) return null;
      return ProfileModel.fromJson(res);
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    if (response.user != null) {
      await recordLoginEvent(
        platform: kIsWeb ? 'web' : 'android',
        deviceInfo: kIsWeb ? 'Web Browser' : 'Android App',
      );
    }

    return response;
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> changePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    // Reset must_change_password flag
    final user = currentAuthUser;
    if (user != null) {
      await _client.from('profiles').update({
        'must_change_password': false,
      }).eq('id', user.id);
    }
  }

  Future<void> resetPasswordForEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> recordLoginEvent({
    required String platform,
    String? ipAddress,
    String? userAgent,
    String? deviceInfo,
  }) async {
    final user = currentAuthUser;
    if (user == null) return;

    try {
      await _client.from('login_events').insert({
        'user_id': user.id,
        'platform': platform,
        'ip_address': ipAddress,
        'user_agent': userAgent,
        'device_info': deviceInfo,
      });
    } catch (e) {
      debugPrint('Could not record login event: $e');
    }
  }
}
