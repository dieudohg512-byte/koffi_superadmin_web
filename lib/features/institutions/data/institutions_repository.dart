import 'package:koffi_superadmin_web/features/institutions/data/benin_commune_departments.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/institution_functional_email.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InstitutionsRepository {
  InstitutionsRepository(this._client);

  final SupabaseClient _client;

  Future<List<SuperAdminInstitution>> listInstitutions() async {
    final rows = await _client.rpc('list_super_admin_institutions');
    final list = List<Map<String, dynamic>>.from(rows as List);
    final institutions = [
      for (final row in list) SuperAdminInstitution.fromRow(row),
    ];
    return _enrich(institutions);
  }

  Future<List<SuperAdminInstitution>> _enrich(
    List<SuperAdminInstitution> institutions,
  ) async {
    final typed = [
      for (final item in institutions)
        if ((item.typeCode == null || item.typeCode!.isEmpty) &&
            item.isCommune)
          item.copyWith(typeCode: 'COMMUNE', typeName: item.typeName ?? 'Commune')
        else
          item,
    ];

    return [
      for (final item in typed) _attachCatalog(item),
    ];
  }

  SuperAdminInstitution _attachCatalog(SuperAdminInstitution item) {
    if (!item.isDepartmentGrouped) return item;
    if (item.departmentName != null && item.departmentName!.isNotEmpty) {
      return item;
    }
    // La Police républicaine porte le nom de sa commune (ex. « Cotonou ») et un
    // slug « pr-cotonou » : on retombe sur le même catalogue IGN.
    final name = beninCommuneDepartments[_communeSlug(item.name)] ??
        (item.slug == null
            ? null
            : beninCommuneDepartments[_geoSlug(item.slug!)] ??
                beninCommuneDepartments[
                    _geoSlug(item.slug!.replaceFirst(RegExp(r'^pr-?'), ''))]);
    if (name == null || name.isEmpty) return item;
    return item.copyWith(departmentName: name);
  }

  static String _communeSlug(String institutionName) {
    var core = institutionName.trim();
    core = core.replaceFirst(
      RegExp(
        r'''^[Cc]ommune\s+(de\s+|d['’]\s*)?''',
      ),
      '',
    );
    core = core.replaceFirst(
      RegExp(r'''^[Mm]airie\s+(de\s+|d['’]\s*)?'''),
      '',
    );
    return _geoSlug(core);
  }

  static String _geoSlug(String input) {
    const fold = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
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
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'ç': 'c',
      'ñ': 'n',
      'œ': 'oe',
      '’': '',
      "'": '',
    };
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      buffer.write(fold[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '');
  }

  Future<List<InstitutionFunctionalEmail>> listFunctionalEmails(
    String institutionId,
  ) async {
    final rows = await _client.rpc(
      'list_institution_functional_emails',
      params: {'p_institution_id': institutionId},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    return [
      for (final row in list) InstitutionFunctionalEmail.fromRow(row),
    ];
  }

  Future<InstitutionActivationResult> activateInstitution(
    String institutionId,
  ) async {
    final raw = await _client.rpc(
      'activate_institution',
      params: {'p_institution_id': institutionId},
    );
    final activation = InstitutionActivationResult.fromJson(_asMap(raw));
    final provisioned = await provisionAccounts(institutionId);
    if (!provisioned.ok || provisioned.result == null) return activation;
    return activation.copyWith(credentials: provisioned.result!.credentials);
  }

  /// Auth + admin_users pour chaque e-mail de fonction (Edge Function).
  ///
  /// Ne régénère PAS les mots de passe des comptes déjà provisionnés.
  Future<ProvisionAccountsOutcome> provisionAccounts(
    String institutionId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'provision-institution-accounts',
        body: {'institution_id': institutionId},
      );
      final data = response.data;
      final map = switch (data) {
        final Map<String, dynamic> m => m,
        final Map m => Map<String, dynamic>.from(m),
        _ => null,
      };
      if (map == null) {
        return const ProvisionAccountsOutcome(
          ok: false,
          message: 'Réponse provisionnement invalide.',
        );
      }
      if (map['error'] != null) {
        return ProvisionAccountsOutcome(
          ok: false,
          message: '${map['error']}',
        );
      }
      final result = InstitutionActivationResult.fromJson(map);
      final created = result.credentials.where((c) => c.created).length;
      final existing = result.credentials.length - created;
      return ProvisionAccountsOutcome(
        ok: true,
        result: result,
        message: created == 0 && existing > 0
            ? 'Comptes déjà provisionnés — mots de passe inchangés.'
            : 'Provisionnement OK ($created créé(s), $existing existant(s)).',
      );
    } on FunctionException catch (error) {
      return ProvisionAccountsOutcome(
        ok: false,
        message: _functionErrorMessage(error),
      );
    } catch (error) {
      return ProvisionAccountsOutcome(
        ok: false,
        message: error.toString(),
      );
    }
  }

  String _functionErrorMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final err = details['error'] ?? details['message'];
      if (err != null && '$err'.trim().isNotEmpty) {
        return 'Échec Auth : $err';
      }
    }
    if (details is String && details.trim().isNotEmpty) {
      return 'Échec Auth : $details';
    }
    final reason = error.reasonPhrase?.trim();
    if (reason != null && reason.isNotEmpty) {
      return 'Échec Auth : $reason (${error.status})';
    }
    return 'Échec Edge Function (${error.status}).';
  }

  Future<List<InstitutionAgentCredential>> listAgentCredentials(
    String institutionId,
  ) async {
    try {
      final rows = await _client.rpc(
        'list_institution_agent_accounts',
        params: {'p_institution_id': institutionId},
      );
      final list = List<Map<String, dynamic>>.from(rows as List);
      return [
        for (final row in list) InstitutionAgentCredential.fromJson(row),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<InstitutionActivationResult> deactivateInstitution(
    String institutionId,
  ) async {
    final raw = await _client.rpc(
      'deactivate_institution',
      params: {'p_institution_id': institutionId},
    );
    return InstitutionActivationResult.fromJson(_asMap(raw));
  }

  Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw StateError('Réponse activation invalide.');
  }
}
