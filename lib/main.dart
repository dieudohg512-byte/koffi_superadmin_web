import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/core/config/supabase_env.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/auth/presentation/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseEnv.normalizeUrl(SupabaseEnv.url),
    publishableKey: SupabaseEnv.anonKey,
  );

  runApp(const KoffiSuperAdminApp());
}

class KoffiSuperAdminApp extends StatelessWidget {
  const KoffiSuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Koffi Super Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AuthGate(),
    );
  }
}
