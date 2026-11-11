import 'package:koffi_superadmin_web/features/tourism/domain/tourism_overview.dart';
import 'package:koffi_superadmin_web/features/tourism/domain/tourism_site.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TourismSitesRepository {
  TourismSitesRepository(this._client);

  final SupabaseClient _client;

  static const siteTypePresets = <String>[
    'Histoire & mémoire',
    'Patrimoine & traditions',
    'Nature & écotourisme',
    'Nature & découverte',
    'Art & culture',
    'Architecture & culture',
    'Plage & balnéaire',
    'Monuments & espaces publics',
  ];

  Future<TourismSuperAdminOverview> overview() async {
    final raw = await _client.rpc('tourism_super_admin_overview');
    return TourismSuperAdminOverview.fromJson(_asMap(raw));
  }

  Future<List<TourismModuleInstitution>> listModuleInstitutions({
    String? query,
  }) async {
    final raw = await _client.rpc(
      'list_tourism_module_institutions',
      params: {
        'p_query': query,
        'p_limit': 80,
      },
    );
    final list = _asList(raw);
    return [
      for (final item in list)
        if (item is Map)
          TourismModuleInstitution.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<List<TourismSite>> listSites({
    bool includeDrafts = true,
    String? query,
  }) async {
    final raw = await _client.rpc(
      'list_tourism_sites',
      params: {
        'p_include_drafts': includeDrafts,
        'p_query': query,
      },
    );
    final list = _asList(raw);
    return [
      for (final item in list)
        if (item is Map) TourismSite.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<List<CommuneOption>> listCommunes({String? query}) async {
    final q = query?.trim();
    final filter = _client.from('communes').select('id, nom, department_id');
    final filtered = (q != null && q.isNotEmpty)
        ? filter.ilike('nom', '%$q%')
        : filter;
    final raw = await filtered.order('nom').limit(80);
    final deptIds = <String>{
      for (final row in raw as List)
        if (row is Map && '${row['department_id'] ?? ''}'.isNotEmpty)
          '${row['department_id']}',
    };
    final deptNames = <String, String>{};
    if (deptIds.isNotEmpty) {
      final depts = await _client
          .from('departments')
          .select('id, nom')
          .inFilter('id', deptIds.toList());
      for (final row in depts as List) {
        if (row is Map) {
          deptNames['${row['id']}'] = '${row['nom'] ?? ''}';
        }
      }
    }
    return [
      for (final row in raw as List)
        if (row is Map)
          CommuneOption(
            id: '${row['id']}',
            name: '${row['nom'] ?? ''}',
            departmentId: '${row['department_id'] ?? ''}',
            departmentName: deptNames['${row['department_id']}'],
          ),
    ];
  }

  Future<TourismSite> upsertSite({
    String? id,
    required String name,
    String? slug,
    String siteType = '',
    String summary = '',
    String? departmentId,
    String? communeId,
    String arrondissementLabel = '',
    String quartierLabel = '',
    required double latitude,
    required double longitude,
    int recognitionRadiusM = 250,
    String? coverImageUrl,
    String? imageSourceUrl,
    String? imageCredit,
    String status = 'draft',
  }) async {
    final raw = await _client.rpc(
      'upsert_tourism_site',
      params: {
        'p_id': id,
        'p_slug': slug,
        'p_name': name,
        'p_site_type': siteType,
        'p_summary': summary,
        'p_department_id': departmentId,
        'p_commune_id': communeId,
        'p_arrondissement_label': arrondissementLabel,
        'p_quartier_label': quartierLabel,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_recognition_radius_m': recognitionRadiusM,
        'p_cover_image_url': coverImageUrl,
        'p_image_source_url': imageSourceUrl,
        'p_image_credit': imageCredit,
        'p_status': status,
      },
    );
    final map = _asMap(raw);
    // Recharger la fiche enrichie (noms territoire).
    final sites = await listSites(includeDrafts: true, query: map['slug']?.toString());
    final match = sites.where((s) => s.id == '${map['id']}').toList();
    if (match.isNotEmpty) return match.first;
    return TourismSite.fromJson(map);
  }

  static List<dynamic> _asList(Object? raw) {
    if (raw is List) return raw;
    if (raw is String && raw.trim().isEmpty) return const [];
    return const [];
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return const {};
  }

}

class CommuneOption {
  const CommuneOption({
    required this.id,
    required this.name,
    required this.departmentId,
    this.departmentName,
  });

  final String id;
  final String name;
  final String departmentId;
  final String? departmentName;

  String get label {
    final dept = (departmentName ?? '').trim();
    return dept.isEmpty ? name : '$name · $dept';
  }
}
