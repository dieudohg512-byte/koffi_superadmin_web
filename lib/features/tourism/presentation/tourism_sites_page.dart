import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/tourism/data/tourism_sites_repository.dart';
import 'package:koffi_superadmin_web/features/tourism/domain/tourism_overview.dart';
import 'package:koffi_superadmin_web/features/tourism/domain/tourism_site.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hub Super Admin Tourisme — aligné prototype SA V2
/// (vue d’ensemble + catalogue national).
class TourismSitesPage extends StatefulWidget {
  const TourismSitesPage({super.key});

  @override
  State<TourismSitesPage> createState() => _TourismSitesPageState();
}

class _TourismSitesPageState extends State<TourismSitesPage>
    with SingleTickerProviderStateMixin {
  late final TourismSitesRepository _repository;
  late final TabController _tabs;
  Future<TourismSuperAdminOverview>? _overviewFuture;
  Future<List<TourismModuleInstitution>>? _institutionsFuture;
  Future<List<TourismSite>>? _sitesFuture;
  final _search = TextEditingController();
  final _instSearch = TextEditingController();
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _repository = TourismSitesRepository(Supabase.instance.client);
    _tabs = TabController(length: 2, vsync: this);
    _reloadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _instSearch.dispose();
    super.dispose();
  }

  void _reloadAll() {
    setState(() {
      _overviewFuture = _repository.overview();
      _institutionsFuture = _repository.listModuleInstitutions(
        query: _instSearch.text.trim().isEmpty ? null : _instSearch.text.trim(),
      );
      _sitesFuture = _repository.listSites(
        includeDrafts: true,
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
    });
  }

  Future<void> _openEditor({TourismSite? site}) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TourismSiteEditorDialog(
        repository: _repository,
        site: site,
      ),
    );
    if (saved == true) _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tourisme & Expérience des visiteurs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Activation institutionnelle, catalogue national et '
                      'publication contrôlée (territoire + GPS + image).',
                      style: TextStyle(fontSize: 13, color: AppTheme.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: _reloadAll,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un site'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabs,
            labelColor: AppTheme.ink,
            tabs: const [
              Tab(text: 'Vue d’ensemble'),
              Tab(text: 'Catalogue & catégories'),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(
                  overviewFuture: _overviewFuture,
                  institutionsFuture: _institutionsFuture,
                  searchController: _instSearch,
                  onSearch: _reloadAll,
                  onOpenCatalog: () => _tabs.animateTo(1),
                ),
                _CatalogTab(
                  sitesFuture: _sitesFuture,
                  searchController: _search,
                  statusFilter: _statusFilter,
                  onStatusChanged: (value) =>
                      setState(() => _statusFilter = value),
                  onSearch: _reloadAll,
                  onEdit: (site) => _openEditor(site: site),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.overviewFuture,
    required this.institutionsFuture,
    required this.searchController,
    required this.onSearch,
    required this.onOpenCatalog,
  });

  final Future<TourismSuperAdminOverview>? overviewFuture;
  final Future<List<TourismModuleInstitution>>? institutionsFuture;
  final TextEditingController searchController;
  final VoidCallback onSearch;
  final VoidCallback onOpenCatalog;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TourismSuperAdminOverview>(
      future: overviewFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Chargement impossible : ${snap.error}',
              style: const TextStyle(color: AppTheme.danger),
            ),
          );
        }
        final data = snap.data!;
        return ListView(
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _KpiCard(
                  label: 'Institutions activées',
                  value: '${data.institutionsEnabled}',
                  hint:
                      '${data.institutionsMinistere} min. · ${data.institutionsPrefecture} préf. · ${data.institutionsMairie} mairies',
                ),
                _KpiCard(
                  label: 'Sites publiés',
                  value: '${data.sitesPublished}',
                  hint: '${data.sitesDraft} brouillons · ${data.sitesTotal} total',
                ),
                _KpiCard(
                  label: 'Communes couvertes',
                  value: '${data.communesCovered}',
                  hint: 'Sites rattachés au référentiel',
                ),
                _KpiCard(
                  label: 'Retours cumulés',
                  value: '${data.feedbacksTotal}',
                  hint: '${data.issuesTotal} dysfonctionnements',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF7F3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD9EEE5)),
              ),
              child: const Text(
                'L’activation rend le module disponible dans l’espace de '
                'l’institution. Elle ne crée pas automatiquement de compétence '
                'ni d’accès aux données d’autres territoires. '
                'Le périmètre suit le ROI (Cabinet CAB / CAB_PREF).',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF346354),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Institutions avec tourism_experience',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onOpenCatalog,
                  child: const Text('Ouvrir le catalogue →'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Filtrer une institution…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: onSearch,
                  icon: const Icon(Icons.filter_list),
                ),
              ),
              onSubmitted: (_) => onSearch(),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<TourismModuleInstitution>>(
              future: institutionsFuture,
              builder: (context, instSnap) {
                if (instSnap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (instSnap.hasError) {
                  return Text(
                    'Institutions : ${instSnap.error}',
                    style: const TextStyle(color: AppTheme.danger),
                  );
                }
                final rows = instSnap.data ?? const [];
                if (rows.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aucune institution n’a encore le module activé.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                  );
                }
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppTheme.border),
                        ListTile(
                          title: Text(
                            rows[i].institutionName,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${rows[i].institutionTypeLabel ?? rows[i].institutionType}'
                            ' · ${rows[i].territoryLabel}',
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Activé',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _CatalogTab extends StatelessWidget {
  const _CatalogTab({
    required this.sitesFuture,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.onSearch,
    required this.onEdit,
  });

  final Future<List<TourismSite>>? sitesFuture;
  final TextEditingController searchController;
  final String? statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onSearch;
  final ValueChanged<TourismSite> onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher un site, une commune…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              tooltip: 'Filtrer',
              onPressed: onSearch,
              icon: const Icon(Icons.filter_list),
            ),
          ),
          onSubmitted: (_) => onSearch(),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Tous'),
                selected: statusFilter == null,
                onSelected: (_) => onStatusChanged(null),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Publiés'),
                selected: statusFilter == 'published',
                onSelected: (_) => onStatusChanged('published'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Brouillons'),
                selected: statusFilter == 'draft',
                onSelected: (_) => onStatusChanged('draft'),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Archivés'),
                selected: statusFilter == 'archived',
                onSelected: (_) => onStatusChanged('archived'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: FutureBuilder<List<TourismSite>>(
            future: sitesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Chargement impossible : ${snapshot.error}',
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                );
              }
              final all = snapshot.data ?? const [];
              final sites = statusFilter == null
                  ? all
                  : [
                      for (final site in all)
                        if (site.status == statusFilter) site,
                    ];
              if (sites.isEmpty) {
                return const Center(
                  child: Text(
                    'Aucun site dans le catalogue.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                );
              }
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  itemCount: sites.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.border),
                  itemBuilder: (context, index) {
                    final site = sites[index];
                    final creditPending =
                        (site.imageCredit ?? '').toLowerCase().contains('vérifier') ||
                        (site.imageCredit ?? '').trim().isEmpty;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: site.coverImageUrl == null
                            ? Container(
                                width: 56,
                                height: 56,
                                color: AppTheme.canvas,
                                child: const Icon(
                                  Icons.landscape_outlined,
                                  color: AppTheme.muted,
                                ),
                              )
                            : Image.network(
                                site.coverImageUrl!,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 56,
                                  height: 56,
                                  color: AppTheme.canvas,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: AppTheme.muted,
                                  ),
                                ),
                              ),
                      ),
                      title: Text(
                        site.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${site.siteType.isEmpty ? 'Type à renseigner' : site.siteType}\n'
                        '${site.territoryLabel}\n'
                        '${site.arrondissementLabel.isEmpty && site.quartierLabel.isEmpty ? 'Arr. / quartier à préciser' : '${site.arrondissementLabel} · ${site.quartierLabel}'}\n'
                        '${site.latitude.toStringAsFixed(4)}, '
                        '${site.longitude.toStringAsFixed(4)} · '
                        'rayon ${site.recognitionRadiusM} m'
                        '${site.feedbackCount > 0 && site.avgRating != null ? ' · ★ ${site.avgRating!.toStringAsFixed(1)} (${site.feedbackCount})' : ''}',
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _StatusChip(status: site.status),
                          const SizedBox(height: 4),
                          Text(
                            creditPending ? 'Droits photo ?' : 'Crédit OK',
                            style: TextStyle(
                              fontSize: 10,
                              color: creditPending
                                  ? const Color(0xFFB45309)
                                  : AppTheme.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () => onEdit(site),
                            child: const Text('Éditer'),
                          ),
                        ],
                      ),
                      onTap: () => onEdit(site),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.ink,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(
              hint!,
              style: const TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'published' => ('Publié', const Color(0xFF047857)),
      'archived' => ('Archivé', AppTheme.muted),
      _ => ('Brouillon', const Color(0xFFB45309)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _TourismSiteEditorDialog extends StatefulWidget {
  const _TourismSiteEditorDialog({
    required this.repository,
    this.site,
  });

  final TourismSitesRepository repository;
  final TourismSite? site;

  @override
  State<_TourismSiteEditorDialog> createState() =>
      _TourismSiteEditorDialogState();
}

class _TourismSiteEditorDialogState extends State<_TourismSiteEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _type;
  late final TextEditingController _summary;
  late final TextEditingController _arr;
  late final TextEditingController _quartier;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _radius;
  late final TextEditingController _image;
  late final TextEditingController _source;
  late final TextEditingController _credit;
  late final TextEditingController _communeSearch;

  String _status = 'draft';
  CommuneOption? _commune;
  List<CommuneOption> _communeOptions = const [];
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final site = widget.site;
    _name = TextEditingController(text: site?.name ?? '');
    _type = TextEditingController(text: site?.siteType ?? '');
    _summary = TextEditingController(text: site?.summary ?? '');
    _arr = TextEditingController(text: site?.arrondissementLabel ?? '');
    _quartier = TextEditingController(text: site?.quartierLabel ?? '');
    _lat = TextEditingController(
      text: site == null ? '' : site.latitude.toString(),
    );
    _lng = TextEditingController(
      text: site == null ? '' : site.longitude.toString(),
    );
    _radius = TextEditingController(
      text: '${site?.recognitionRadiusM ?? 250}',
    );
    _image = TextEditingController(text: site?.coverImageUrl ?? '');
    _source = TextEditingController(text: site?.imageSourceUrl ?? '');
    _credit = TextEditingController(text: site?.imageCredit ?? '');
    _communeSearch = TextEditingController(text: site?.communeName ?? '');
    _status = site?.status ?? 'draft';
    if (site?.communeId != null) {
      _commune = CommuneOption(
        id: site!.communeId!,
        name: site.communeName ?? '',
        departmentId: site.departmentId ?? '',
        departmentName: site.departmentName,
      );
    }
    _loadCommunes();
  }

  @override
  void dispose() {
    _name.dispose();
    _type.dispose();
    _summary.dispose();
    _arr.dispose();
    _quartier.dispose();
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    _image.dispose();
    _source.dispose();
    _credit.dispose();
    _communeSearch.dispose();
    super.dispose();
  }

  Future<void> _loadCommunes() async {
    try {
      final rows = await widget.repository.listCommunes(
        query: _communeSearch.text.trim().isEmpty
            ? null
            : _communeSearch.text.trim(),
      );
      if (!mounted) return;
      setState(() => _communeOptions = rows);
    } catch (_) {
      // La sélection manuelle reste possible via le champ recherche.
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
    final radius = int.tryParse(_radius.text.trim()) ?? 250;
    if (name.isEmpty || lat == null || lng == null) {
      setState(() => _error = 'Nom et coordonnées GPS obligatoires.');
      return;
    }
    if (_status == 'published' &&
        (_commune == null ||
            _image.text.trim().isEmpty ||
            _type.text.trim().isEmpty)) {
      setState(
        () => _error =
            'Publication : type + commune + image de couverture requises.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.upsertSite(
        id: widget.site?.id,
        name: name,
        siteType: _type.text.trim(),
        summary: _summary.text.trim(),
        departmentId: _commune?.departmentId.isEmpty == true
            ? null
            : _commune?.departmentId,
        communeId: _commune?.id,
        arrondissementLabel: _arr.text.trim(),
        quartierLabel: _quartier.text.trim(),
        latitude: lat,
        longitude: lng,
        recognitionRadiusM: radius,
        coverImageUrl: _image.text.trim().isEmpty ? null : _image.text.trim(),
        imageSourceUrl:
            _source.text.trim().isEmpty ? null : _source.text.trim(),
        imageCredit: _credit.text.trim().isEmpty ? null : _credit.text.trim(),
        status: _status,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeValue = TourismSitesRepository.siteTypePresets.contains(
          _type.text.trim(),
        )
        ? _type.text.trim()
        : null;

    return AlertDialog(
      title: Text(
        widget.site == null ? 'Nouveau site touristique' : 'Éditer le site',
      ),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Règle de publication : nom + type + image + département + '
                'commune + GPS + rayon de reconnaissance.',
                style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nom officiel *'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('type-${typeValue ?? 'custom'}'),
                initialValue: typeValue,
                decoration: const InputDecoration(labelText: 'Type / catégorie'),
                items: [
                  for (final type in TourismSitesRepository.siteTypePresets)
                    DropdownMenuItem(value: type, child: Text(type)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type.text = value);
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _type,
                decoration: const InputDecoration(
                  labelText: 'Type libre (si hors liste)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _summary,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description courte',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _communeSearch,
                decoration: const InputDecoration(
                  labelText: 'Commune *',
                  hintText: 'Rechercher dans le référentiel…',
                ),
                onChanged: (_) => _loadCommunes(),
              ),
              if (_communeOptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 140),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _communeOptions.length,
                    itemBuilder: (context, index) {
                      final option = _communeOptions[index];
                      final selected = _commune?.id == option.id;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        title: Text(option.label),
                        onTap: () {
                          setState(() {
                            _commune = option;
                            _communeSearch.text = option.name;
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
              if (_commune != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Sélection : ${_commune!.label}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _arr,
                      decoration: const InputDecoration(
                        labelText: 'Arrondissement',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _quartier,
                      decoration: const InputDecoration(
                        labelText: 'Village / quartier',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                      ],
                      decoration: const InputDecoration(labelText: 'Latitude *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                      ],
                      decoration:
                          const InputDecoration(labelText: 'Longitude *'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _radius,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Rayon GPS (m)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'URL image de couverture',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _source,
                decoration: const InputDecoration(
                  labelText: 'Source / URL d’autorisation',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _credit,
                decoration: const InputDecoration(
                  labelText: 'Auteur / crédit / licence',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('status-$_status'),
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Publication'),
                items: const [
                  DropdownMenuItem(value: 'draft', child: Text('Brouillon')),
                  DropdownMenuItem(value: 'published', child: Text('Publié')),
                  DropdownMenuItem(value: 'archived', child: Text('Archivé')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.danger, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _status == 'draft'
                      ? 'Enregistrer le brouillon'
                      : 'Enregistrer',
                ),
        ),
      ],
    );
  }
}
