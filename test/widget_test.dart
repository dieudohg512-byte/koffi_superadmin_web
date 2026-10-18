import 'package:flutter_test/flutter_test.dart';
import 'package:koffi_superadmin_web/core/config/supabase_env.dart';

void main() {
  test('SupabaseEnv.normalizeUrl retire les suffixes API', () {
    expect(
      SupabaseEnv.normalizeUrl('https://example.supabase.co/rest/v1/'),
      'https://example.supabase.co',
    );
    expect(
      SupabaseEnv.normalizeUrl('https://example.supabase.co'),
      'https://example.supabase.co',
    );
  });
}
