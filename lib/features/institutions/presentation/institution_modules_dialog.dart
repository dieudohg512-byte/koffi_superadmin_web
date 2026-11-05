import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/institution_module.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';

/// Sélection des modules à l'activation ou en édition (espace super-admin web).
Future<List<String>?> showInstitutionModulesDialog({
  required BuildContext context,
  required SuperAdminInstitution institution,
  required bool activating,
}) {
  final initial = institution.enabledModules.isNotEmpty
      ? institution.enabledModules
      : InstitutionModule.defaultsForType(institution.typeCode);
  return showDialog<List<String>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _InstitutionModulesDialog(
      institution: institution,
      activating: activating,
      initialModules: initial,
    ),
  );
}

class _InstitutionModulesDialog extends StatefulWidget {
  const _InstitutionModulesDialog({
    required this.institution,
    required this.activating,
    required this.initialModules,
  });

  final SuperAdminInstitution institution;
  final bool activating;
  final List<String> initialModules;

  @override
  State<_InstitutionModulesDialog> createState() =>
      _InstitutionModulesDialogState();
}

class _InstitutionModulesDialogState extends State<_InstitutionModulesDialog> {
  late final Set<String> _selected = {...widget.initialModules};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.activating ? 'Modules à activer' : 'Modifier les modules',
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.institution.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cochez uniquement les fonctions dont cette institution a besoin. '
              'Le tableau de bord agent s’adapte automatiquement.',
              style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            for (final code in InstitutionModule.all)
              CheckboxListTile(
                key: Key('institution-module-$code'),
                value: _selected.contains(code),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  InstitutionModule.label(code),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  InstitutionModule.hint(code),
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selected.add(code);
                    } else {
                      _selected.remove(code);
                    }
                  });
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const Key('institution-modules-confirm'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selected.toList()),
          child: Text(widget.activating ? 'Activer' : 'Enregistrer'),
        ),
      ],
    );
  }
}
