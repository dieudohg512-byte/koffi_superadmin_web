import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/features/auth/presentation/login_page.dart';
import 'package:koffi_superadmin_web/features/shell/presentation/super_admin_shell.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Affiche le login si aucune session Supabase, sinon le shell.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginPage();
        }
        return const SuperAdminShell();
      },
    );
  }
}
