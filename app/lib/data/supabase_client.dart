import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  SupabaseConfig._();

  // Default values can be passed via --dart-define or loaded from config
  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pvpvngoepfifmhsnaxoh.supabase.co',
  );

  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_mQRTX6xJbB_SMzWvAYiQYg_m3NFBgy0',
  );

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize({String? url, String? anonKey}) async {
    try {
      await Supabase.initialize(
        url: url ?? defaultUrl,
        // ignore: deprecated_member_use
        anonKey: anonKey ?? defaultAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
      _initialized = true;
    } catch (e) {
      // In testing or when credentials are not yet configured, catch initialization
      _initialized = false;
    }
  }

  static SupabaseClient? _fallbackClient;

  static SupabaseClient get client {
    if (_initialized) {
      return Supabase.instance.client;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      _fallbackClient ??= SupabaseClient(
        defaultUrl,
        defaultAnonKey,
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
        ),
      );
      return _fallbackClient!;
    }
  }
}
