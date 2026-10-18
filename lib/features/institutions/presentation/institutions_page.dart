import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/core/state/activated_communes_store.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/institutions/data/institutions_repository.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';
import 'package:koffi_superadmin_web/features/institutions/presentation/institution_emails_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstitutionsPage extends StatefulWidget {
  const InstitutionsPage({super.key});

  @override
  State<InstitutionsPage> createState() => _InstitutionsPageState();
}

class _InstitutionsPageState extends State<InstitutionsPage> {
  late final InstitutionsRepository _repository;
  Future<List<SuperAdminInstitution>>? _future;
  String? _busyId;
  InstitutionTypeFilter _typeFilter = InstitutionTypeFilter.all;
  final _search = TextEditingController();

  /// Départements cochés (vide = tous).
  final Set<String> _selectedDepartmentKeys = {};

  /// null = tous ; true = actives ; false = inactives.
  bool? _statusFilter;

  /// Accordion exclusif : une seule clé ouverte à la fois.
  String? _expandedDepartmentKey;

  /// Les deux bandes de filtres sont repliées pour laisser la liste visible.
  bool _filtersOpen = false;
  bool _departmentsOpen = false;

  @override
  void initState() {
    super.initState();
    _repository = InstitutionsRepository(Supabase.instance.client);
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<SuperAdminInstitution>> _load() async {
    final rows = await _repository.listInstitutions();
    activatedCommunesStore.updateFromInstitutions(rows);
    return rows;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openEmails(SuperAdminInstitution item) {
    return showInstitutionEmailsDialog(
      context: context,
      repository: _repository,
      institutionId: item.id,
      institutionName: item.name,
    );
  }

  Future<void> _onToggle(SuperAdminInstitution item, bool nextValue) async {
    if (_busyId != null) return;
    setState(() => _busyId = item.id);
    var openEmailsAfter = false;
    var emailsTitle = item.name;
    try {
      final result = nextValue
          ? await _repository.activateInstitution(item.id)
          : await _repository.deactivateInstitution(item.id);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? '${result.name} activée' : '${result.name} désactivée',
          ),
        ),
      );
      if (nextValue) {
        openEmailsAfter = true;
        emailsTitle = result.name.isNotEmpty ? result.name : item.name;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_friendlyError(e)),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
    if (openEmailsAfter && mounted) {
      await showInstitutionEmailsDialog(
        context: context,
        repository: _repository,
        institutionId: item.id,
        institutionName: emailsTitle,
      );
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('not_super_admin')) {
      return 'Compte non autorisé (super-admin requis).';
    }
    if (text.contains('institution_not_found')) {
      return 'Institution introuvable.';
    }
    return 'Action impossible. Réessayez.';
  }

  String _departmentKey(SuperAdminInstitution item) =>
      item.departmentId ?? 'none:${item.departmentLabel}';

  List<_DepartmentOption> _departmentOptions(
    List<SuperAdminInstitution> grouped,
  ) {
    final map = <String, String>{};
    for (final item in grouped) {
      map.putIfAbsent(_departmentKey(item), () => item.departmentLabel);
    }
    final options = [
      for (final e in map.entries)
        _DepartmentOption(key: e.key, label: e.value),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return options;
  }

  List<SuperAdminInstitution> _filtered(List<SuperAdminInstitution> rows) {
    final q = _search.text.trim().toLowerCase();
    return [
      for (final item in rows)
        if (_typeFilter.matches(item) &&
            (_statusFilter == null ||
                item.platformEnabled == _statusFilter) &&
            (_selectedDepartmentKeys.isEmpty ||
                !item.isDepartmentGrouped ||
                _selectedDepartmentKeys.contains(_departmentKey(item))) &&
            (q.isEmpty || _matchesSearch(item, q)))
          item,
    ];
  }

  bool _matchesSearch(SuperAdminInstitution item, String q) {
    final query = _fold(q);
    if (_fold(item.name).contains(query)) return true;
    if (_fold(item.slug ?? '').contains(query)) return true;
    if (_fold(item.sigle ?? '').contains(query)) return true;
    if (_fold(item.departmentLabel).contains(query)) return true;
    return false;
  }

  String _fold(String input) => _foldText(input);

  List<_DepartmentGroup> _departmentGroups(
    List<SuperAdminInstitution> items, {
    required String sectionPrefix,
  }) {
    final map = <String, List<SuperAdminInstitution>>{};
    final labels = <String, String>{};
    for (final item in items) {
      final key = _departmentKey(item);
      labels[key] = item.departmentLabel;
      (map[key] ??= []).add(item);
    }
    for (final list in map.values) {
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    }
    final keys = map.keys.toList()
      ..sort(
        (a, b) => labels[a]!.toLowerCase().compareTo(labels[b]!.toLowerCase()),
      );
    return [
      for (final key in keys)
        _DepartmentGroup(
          key: '$sectionPrefix:$key',
          label: labels[key]!,
          communes: map[key]!,
        ),
    ];
  }

  /// Rend une section regroupée par département (communes ou police).
  List<Widget> _departmentSection({
    required String title,
    required List<_DepartmentGroup> groups,
    required String? expandedKey,
    required String countNoun,
  }) {
    if (groups.isEmpty) return const [];
    return [
      _SectionLabel(
        title,
        detail: () {
          final total = groups.fold<int>(0, (n, g) => n + g.communes.length);
          final active = groups.fold<int>(
            0,
            (n, g) => n + g.communes.where((c) => c.platformEnabled).length,
          );
          return '$total · $active active${active > 1 ? 's' : ''}';
        }(),
      ),
      const SizedBox(height: 8),
      for (final group in groups) ...[
        Card(
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: ValueKey('dept-${group.key}-$expandedKey'),
            initiallyExpanded: expandedKey == group.key,
            maintainState: true,
            onExpansionChanged: (expanded) {
              setState(() {
                if (expanded) {
                  _expandedDepartmentKey = group.key;
                } else if (_expandedDepartmentKey == group.key) {
                  _expandedDepartmentKey = null;
                }
              });
            },
            title: Text(
              group.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              () {
                final total = group.communes.length;
                final active =
                    group.communes.where((c) => c.platformEnabled).length;
                final plural = total > 1 ? 's' : '';
                return '$total $countNoun$plural'
                    ' · $active active${active > 1 ? 's' : ''}';
              }(),
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            children: [
              _InstitutionTable(
                items: group.communes,
                busyId: _busyId,
                showTypeColumn: false,
                onToggle: _onToggle,
                onOpenEmails: _openEmails,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 12),
    ];
  }

  /// Clé d’accordion à ouvrir (sans muter l’état pendant le build).
  String? _effectiveExpandedKey(List<_DepartmentGroup> groups) {
    if (groups.isEmpty) return null;
    if (_expandedDepartmentKey != null &&
        groups.any((g) => g.key == _expandedDepartmentKey)) {
      return _expandedDepartmentKey;
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final byDeptName = [
        for (final g in groups)
          if (g.label.toLowerCase().contains(q)) g,
      ];
      if (byDeptName.length == 1) return byDeptName.first.key;
      if (groups.length == 1) return groups.first.key;
    }
    if (_selectedDepartmentKeys.length == 1) {
      final sel = _selectedDepartmentKeys.first;
      final match = [for (final g in groups) if (g.key.endsWith(':$sel')) g];
      if (match.length == 1) return match.first.key;
    }
    if (groups.length == 1) return groups.first.key;
    return null;
  }

  List<String> _searchSuggestions(
    List<_DepartmentOption> departments,
    List<SuperAdminInstitution> communes,
  ) {
    final q = _foldText(_search.text.trim());
    if (q.isEmpty) return const [];
    final out = <String>[];
    for (final d in departments) {
      if (_foldText(d.label).contains(q)) {
        out.add('Département · ${d.label}');
      }
    }
    for (final c in communes) {
      if (_foldText(c.name).contains(q) ||
          _foldText(c.slug ?? '').contains(q)) {
        out.add('Commune · ${c.name}');
      }
      if (out.length >= 12) break;
    }
    return out;
  }

  void _applySuggestion(
    String suggestion,
    List<_DepartmentOption> departments,
  ) {
    if (suggestion.startsWith('Département · ')) {
      final label = suggestion.substring('Département · '.length);
      final option = departments.cast<_DepartmentOption?>().firstWhere(
            (d) => d?.label == label,
            orElse: () => null,
          );
      setState(() {
        _search.text = label;
        _departmentsOpen = true;
        if (option != null) {
          _selectedDepartmentKeys
            ..clear()
            ..add(option.key);
          _expandedDepartmentKey = null;
        }
      });
      return;
    }
    if (suggestion.startsWith('Commune · ')) {
      final name = suggestion.substring('Commune · '.length);
      setState(() => _search.text = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 12, compact ? 12 : 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FutureBuilder<List<SuperAdminInstitution>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _friendlyError(snapshot.error!),
                          style: const TextStyle(color: AppTheme.danger),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }

                final allRows =
                    snapshot.data ?? const <SuperAdminInstitution>[];
                if (allRows.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune institution.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  );
                }

                final allGrouped = [
                  for (final item in allRows)
                    if (item.isDepartmentGrouped) item,
                ];
                final deptOptions = _departmentOptions(allGrouped);
                final rows = _filtered(allRows);
                final communes = [
                  for (final item in rows)
                    if (item.isCommune) item,
                ];
                final police = [
                  for (final item in rows)
                    if (item.isPoliceRepublicaine) item,
                ];
                final others = [
                  for (final item in rows)
                    if (!item.isDepartmentGrouped) item,
                ];
                final communeGroups =
                    _departmentGroups(communes, sectionPrefix: 'commune');
                final policeGroups =
                    _departmentGroups(police, sectionPrefix: 'police');
                final expandedKey = _effectiveExpandedKey(
                  [...communeGroups, ...policeGroups],
                );
                final suggestions =
                    _searchSuggestions(deptOptions, allGrouped);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FilterBar(
                      typeFilter: _typeFilter,
                      onTypeChanged: (v) => setState(() => _typeFilter = v),
                      statusFilter: _statusFilter,
                      onStatusChanged: (v) =>
                          setState(() => _statusFilter = v),
                      searchController: _search,
                      onSearchChanged: () => setState(() {}),
                      suggestions: suggestions,
                      onSuggestionSelected: (s) =>
                          _applySuggestion(s, deptOptions),
                      departmentOptions: deptOptions,
                      selectedDepartmentKeys: _selectedDepartmentKeys,
                      onToggleDepartment: (key) {
                        setState(() {
                          if (_selectedDepartmentKeys.contains(key)) {
                            _selectedDepartmentKeys.remove(key);
                          } else {
                            _selectedDepartmentKeys.add(key);
                          }
                          if (_selectedDepartmentKeys.length == 1) {
                            _expandedDepartmentKey = null;
                          }
                        });
                      },
                      onClearDepartments: () {
                        setState(_selectedDepartmentKeys.clear);
                      },
                      filtersOpen: _filtersOpen,
                      departmentsOpen: _departmentsOpen,
                      onToggleFilters: () =>
                          setState(() => _filtersOpen = !_filtersOpen),
                      onToggleDepartments: () => setState(
                        () => _departmentsOpen = !_departmentsOpen,
                      ),
                      onReset: () {
                        setState(() {
                          _typeFilter = InstitutionTypeFilter.all;
                          _statusFilter = null;
                          _search.clear();
                          _selectedDepartmentKeys.clear();
                        });
                      },
                      onReload: _busyId == null ? _reload : null,
                      resultCount: rows.length,
                      totalCount: allRows.length,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: rows.isEmpty
                          ? const Center(
                              child: Text(
                                'Aucune institution pour ce filtre.',
                                style: TextStyle(color: AppTheme.muted),
                              ),
                            )
                          : ListView(
                              children: [
                                ..._departmentSection(
                                  title: 'Communes par département',
                                  groups: communeGroups,
                                  expandedKey: expandedKey,
                                  countNoun: 'commune',
                                ),
                                ..._departmentSection(
                                  title: 'Police républicaine par département',
                                  groups: policeGroups,
                                  expandedKey: expandedKey,
                                  countNoun: 'commissariat',
                                ),
                                if (others.isNotEmpty) ...[
                                  _SectionLabel(
                                    'Autres institutions',
                                    detail: '${others.length}',
                                  ),
                                  const SizedBox(height: 8),
                                  Card(
                                    clipBehavior: Clip.antiAlias,
                                    child: _InstitutionTable(
                                      items: others,
                                      busyId: _busyId,
                                      showTypeColumn: true,
                                      onToggle: _onToggle,
                                      onOpenEmails: _openEmails,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.onTypeChanged,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.searchController,
    required this.onSearchChanged,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.departmentOptions,
    required this.selectedDepartmentKeys,
    required this.onToggleDepartment,
    required this.onClearDepartments,
    required this.filtersOpen,
    required this.departmentsOpen,
    required this.onToggleFilters,
    required this.onToggleDepartments,
    required this.onReset,
    required this.onReload,
    required this.resultCount,
    required this.totalCount,
  });

  final InstitutionTypeFilter typeFilter;
  final ValueChanged<InstitutionTypeFilter> onTypeChanged;
  final bool? statusFilter;
  final ValueChanged<bool?> onStatusChanged;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionSelected;
  final List<_DepartmentOption> departmentOptions;
  final Set<String> selectedDepartmentKeys;
  final ValueChanged<String> onToggleDepartment;
  final VoidCallback onClearDepartments;
  final bool filtersOpen;
  final bool departmentsOpen;
  final VoidCallback onToggleFilters;
  final VoidCallback onToggleDepartments;
  final VoidCallback onReset;
  final VoidCallback? onReload;
  final int resultCount;
  final int totalCount;

  bool get _filtersActive =>
      typeFilter != InstitutionTypeFilter.all ||
      statusFilter != null ||
      searchController.text.trim().isNotEmpty ||
      selectedDepartmentKeys.isNotEmpty;

  String get _filterSummary {
    final parts = <String>[
      typeFilter.label,
      if (statusFilter == true) 'Actives',
      if (statusFilter == false) 'Inactives',
      if (searchController.text.trim().isNotEmpty)
        '« ${searchController.text.trim()} »',
    ];
    return parts.join(' · ');
  }

  String get _departmentSummary {
    if (selectedDepartmentKeys.isEmpty) return 'Tous';
    final labels = [
      for (final option in departmentOptions)
        if (selectedDepartmentKeys.contains(option.key)) option.label,
    ];
    if (labels.isEmpty) return '${selectedDepartmentKeys.length} sélectionnés';
    if (labels.length <= 3) return labels.join(', ');
    return '${labels.length} départements';
  }

  @override
  Widget build(BuildContext context) {
    final q = _foldText(searchController.text.trim());
    final suggestedDepartments = [
      for (final option in departmentOptions)
        if (selectedDepartmentKeys.contains(option.key) ||
            q.isEmpty ||
            _foldText(option.label).contains(q))
          option,
    ];
    final shown =
        resultCount == totalCount ? '$resultCount' : '$resultCount / $totalCount';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Littoral, Abomey, slug…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
                          },
                          icon: const Icon(Icons.close, size: 16),
                        ),
                ),
              ),
            ),
            if (_filtersActive)
              TextButton(onPressed: onReset, child: const Text('Réinitialiser')),
            IconButton(
              tooltip: 'Rafraîchir',
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  avatar: Icon(
                    suggestion.startsWith('Département')
                        ? Icons.map_outlined
                        : Icons.location_city_outlined,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                  label: Text(
                    suggestion,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => onSuggestionSelected(suggestion),
                  backgroundColor: AppTheme.surface,
                  side: const BorderSide(color: AppTheme.border),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        _FoldPanel(
          title: 'Filtres',
          summary: _filterSummary,
          icon: Icons.tune,
          expanded: filtersOpen,
          highlighted: typeFilter != InstitutionTypeFilter.all ||
              statusFilter != null,
          onToggle: onToggleFilters,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in InstitutionTypeFilter.values)
                _choiceChip(
                  label: filter.label,
                  selected: typeFilter == filter,
                  onSelected: () => onTypeChanged(filter),
                ),
              _choiceChip(
                label: 'Actives',
                selected: statusFilter == true,
                onSelected: () =>
                    onStatusChanged(statusFilter == true ? null : true),
              ),
              _choiceChip(
                label: 'Inactives',
                selected: statusFilter == false,
                onSelected: () =>
                    onStatusChanged(statusFilter == false ? null : false),
              ),
            ],
          ),
        ),
        if (departmentOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _FoldPanel(
            title: 'Départements',
            summary: _departmentSummary,
            icon: Icons.map_outlined,
            expanded: departmentsOpen,
            highlighted: selectedDepartmentKeys.isNotEmpty,
            onToggle: onToggleDepartments,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedDepartmentKeys.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onClearDepartments,
                      child: const Text('Tout effacer'),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final option in suggestedDepartments)
                      _choiceChip(
                        label: option.label,
                        selected: selectedDepartmentKeys.contains(option.key),
                        onSelected: () => onToggleDepartment(option.key),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          '$shown institution${resultCount > 1 ? 's' : ''}',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
      ],
    );
  }

  Widget _choiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      selectedColor: AppTheme.accentSoft,
      checkmarkColor: AppTheme.accent,
      labelStyle: TextStyle(
        color: selected ? AppTheme.accent : AppTheme.ink,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected
            ? AppTheme.accent.withValues(alpha: 0.45)
            : AppTheme.border,
      ),
      backgroundColor: AppTheme.surface,
    );
  }
}

class _FoldPanel extends StatelessWidget {
  const _FoldPanel({
    required this.title,
    required this.summary,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.highlighted = false,
  });

  final String title;
  final String summary;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: highlighted ? AppTheme.accent : AppTheme.muted,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        color: highlighted ? AppTheme.accent : AppTheme.muted,
                        fontWeight:
                            highlighted ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            alignment: Alignment.topCenter,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

class _InstitutionTable extends StatelessWidget {
  const _InstitutionTable({
    required this.items,
    required this.busyId,
    required this.showTypeColumn,
    required this.onToggle,
    required this.onOpenEmails,
  });

  final List<SuperAdminInstitution> items;
  final String? busyId;
  final bool showTypeColumn;
  final Future<void> Function(SuperAdminInstitution, bool) onToggle;
  final Future<void> Function(SuperAdminInstitution) onOpenEmails;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 760) {
      return Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              title: Text(
                items[i].name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  if (showTypeColumn) items[i].typeLabel,
                  items[i].slug ?? '—',
                  '${items[i].mailboxCount} boîtes',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busyId == items[i].id)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: items[i].platformEnabled,
                      onChanged: busyId != null
                          ? null
                          : (value) => onToggle(items[i], value),
                    ),
                  if (items[i].canViewEmails)
                    IconButton(
                      tooltip: 'Voir les e-mails',
                      onPressed:
                          busyId != null ? null : () => onOpenEmails(items[i]),
                      icon: const Icon(Icons.mail_outline, size: 20),
                    ),
                ],
              ),
            ),
            if (i != items.length - 1) const Divider(height: 1),
          ],
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          if (showTypeColumn) const DataColumn(label: Text('Type')),
          const DataColumn(label: Text('Nom')),
          const DataColumn(label: Text('Slug')),
          const DataColumn(label: Text('Statut')),
          const DataColumn(label: Text('Boîtes'), numeric: true),
          const DataColumn(label: Text('Actions')),
        ],
        rows: [
          for (final item in items)
            DataRow(
              cells: [
                if (showTypeColumn) DataCell(Text(item.typeLabel)),
                DataCell(
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text(
                    item.slug ?? '—',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.muted,
                    ),
                  ),
                ),
                DataCell(_StatusBadge(active: item.platformEnabled)),
                DataCell(Text('${item.mailboxCount}')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (busyId == item.id)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Switch(
                          value: item.platformEnabled,
                          onChanged: busyId != null
                              ? null
                              : (value) => onToggle(item, value),
                        ),
                      if (item.canViewEmails)
                        IconButton(
                          tooltip: 'Voir les e-mails',
                          onPressed:
                              busyId != null ? null : () => onOpenEmails(item),
                          icon: const Icon(Icons.mail_outline, size: 20),
                        ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.detail});

  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppTheme.ink,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 8),
            Text(
              detail!,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: (active ? AppTheme.accent : AppTheme.muted)
            .withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          active ? 'Actif' : 'Inactif',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? AppTheme.accent : AppTheme.muted,
          ),
        ),
      ),
    );
  }
}

class _DepartmentOption {
  const _DepartmentOption({required this.key, required this.label});

  final String key;
  final String label;
}

class _DepartmentGroup {
  const _DepartmentGroup({
    required this.key,
    required this.label,
    required this.communes,
  });

  final String key;
  final String label;
  final List<SuperAdminInstitution> communes;
}

String _foldText(String input) {
  const fold = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'œ': 'oe',
    '’': '',
    "'": '',
  };
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(fold[char] ?? char);
  }
  return buffer.toString();
}
