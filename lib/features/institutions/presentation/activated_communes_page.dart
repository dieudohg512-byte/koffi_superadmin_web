import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/core/state/activated_communes_store.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/institutions/data/institutions_repository.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivatedCommunesPage extends StatefulWidget {
  const ActivatedCommunesPage({super.key});

  @override
  State<ActivatedCommunesPage> createState() => _ActivatedCommunesPageState();
}

class _ActivatedCommunesPageState extends State<ActivatedCommunesPage> {
  var _loading = false;

  @override
  void initState() {
    super.initState();
    if (activatedCommunesStore.count == 0) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final rows =
          await InstitutionsRepository(Supabase.instance.client).listInstitutions();
      activatedCommunesStore.updateFromInstitutions(rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_DeptSection> _sections(List<SuperAdminInstitution> items) {
    final map = <String, List<SuperAdminInstitution>>{};
    for (final item in items) {
      (map[item.departmentLabel] ??= []).add(item);
    }
    final labels = map.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return [
      for (final label in labels)
        _DeptSection(label: label, communes: map[label]!),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: activatedCommunesStore,
      builder: (context, _) {
        final items = activatedCommunesStore.items;
        final sections = _sections(items);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${items.length} commune${items.length > 1 ? 's' : ''} activée${items.length > 1 ? 's' : ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rafraîchir',
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Liste des communes / mairies activées (platform_enabled), par département.',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading && items.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucune commune activée pour le moment.',
                              style: TextStyle(color: AppTheme.muted),
                            ),
                          )
                        : Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListView.builder(
                              itemCount: sections.length,
                              itemBuilder: (context, index) {
                                final section = sections[index];
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      color: const Color(0xFFF9FAFB),
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        10,
                                        16,
                                        8,
                                      ),
                                      child: Text(
                                        '${section.label} (${section.communes.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: AppTheme.ink,
                                        ),
                                      ),
                                    ),
                                    for (final item in section.communes)
                                      ListTile(
                                        leading: const Icon(
                                          Icons.location_city_outlined,
                                          color: AppTheme.accent,
                                        ),
                                        title: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: item.slug == null
                                            ? null
                                            : Text(
                                                item.slug!,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                  color: AppTheme.muted,
                                                ),
                                              ),
                                        trailing: Text(
                                          '${item.mailboxCount} boîtes',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.muted,
                                          ),
                                        ),
                                      ),
                                    const Divider(height: 1),
                                  ],
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeptSection {
  const _DeptSection({required this.label, required this.communes});

  final String label;
  final List<SuperAdminInstitution> communes;
}
