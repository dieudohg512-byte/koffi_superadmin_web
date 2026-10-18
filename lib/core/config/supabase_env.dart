/// Mêmes valeurs que citoyen_chat_app/lib/core/config/supabase_env.dart
abstract final class SupabaseEnv {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ubfjthfghotvalhfuora.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_VNMsI8ZcjE4hQAdldu7J3A_KIXeUQf5',
  );

  /// Accepte `https://xxx.supabase.co` ou une URL copiée avec `/rest/v1`.
  static String normalizeUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    for (final suffix in const [
      '/rest/v1',
      '/auth/v1',
      '/functions/v1',
      '/storage/v1',
    ]) {
      if (value.endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
      }
    }
    return value;
  }
}
