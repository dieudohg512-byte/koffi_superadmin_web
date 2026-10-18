import 'package:koffi_superadmin_web/features/institutions/domain/institution_mailbox.dart';

class SuperAdminInstitution {
  const SuperAdminInstitution({
    required this.id,
    required this.name,
    this.sigle,
    this.slug,
    required this.platformEnabled,
    this.platformActivatedAt,
    this.departmentId,
    this.departmentName,
    this.mailboxCount = 0,
    this.typeId,
    this.typeCode,
    this.typeName,
  });

  final String id;
  final String name;
  final String? sigle;
  final String? slug;

  /// Statut d’activation plateforme (`platform_enabled` / `actif` RPC).
  final bool platformEnabled;
  final DateTime? platformActivatedAt;
  final String? departmentId;
  final String? departmentName;
  final int mailboxCount;
  final String? typeId;
  final String? typeCode;
  final String? typeName;

  bool get actif => platformEnabled;

  bool get isCommune {
    if (isPoliceRepublicaine) return false;
    final code = typeCodeUpper;
    if (code == 'COMMUNE' || code == 'MAIRIE') return true;
    final type = (typeName ?? '').toLowerCase();
    if (type.contains('commune') || type.contains('mairie')) return true;
    final n = name.trim().toLowerCase();
    return n.startsWith('commune de ') ||
        n.startsWith("commune d'") ||
        n.startsWith('commune d’') ||
        n.startsWith('mairie de ') ||
        n.startsWith('mairie ');
  }

  bool get isPoliceRepublicaine {
    if (typeCodeUpper == 'POLICE_REPUBLICAINE') return true;
    return (typeName ?? '').toLowerCase().contains('police républicaine') ||
        (typeName ?? '').toLowerCase().contains('police republicaine');
  }

  /// Institutions rattachées à une commune : regroupées par département.
  bool get isDepartmentGrouped => isCommune || isPoliceRepublicaine;

  /// Bouton « Voir les e-mails » si boîtes déjà créées ou institution active.
  bool get canViewEmails => mailboxCount > 0 || platformEnabled;

  String get typeLabel => typeName ?? typeCode ?? '—';

  String get typeCodeUpper => (typeCode ?? '').toUpperCase();

  String get departmentLabel =>
      (departmentName?.trim().isNotEmpty ?? false)
          ? departmentName!.trim()
          : 'Sans département';

  SuperAdminInstitution copyWith({
    String? departmentId,
    String? departmentName,
    String? typeCode,
    String? typeName,
  }) {
    return SuperAdminInstitution(
      id: id,
      name: name,
      sigle: sigle,
      slug: slug,
      platformEnabled: platformEnabled,
      platformActivatedAt: platformActivatedAt,
      departmentId: departmentId ?? this.departmentId,
      departmentName: departmentName ?? this.departmentName,
      mailboxCount: mailboxCount,
      typeId: typeId,
      typeCode: typeCode ?? this.typeCode,
      typeName: typeName ?? this.typeName,
    );
  }

  factory SuperAdminInstitution.fromRow(Map<String, dynamic> row) {
    final platformEnabled = row['platform_enabled'] == true ||
        row['actif'] == true;
    return SuperAdminInstitution(
      id: '${row['id'] ?? ''}',
      name: '${row['nom'] ?? ''}',
      sigle: _nullableText(row['sigle']),
      slug: _nullableText(row['slug']),
      platformEnabled: platformEnabled,
      platformActivatedAt:
          DateTime.tryParse('${row['platform_activated_at'] ?? ''}'),
      departmentId: _nullableText(row['department_id']),
      departmentName: _nullableText(
        row['department_nom'] ?? row['department_name'],
      ),
      mailboxCount: switch (row['mailbox_count']) {
        final int n => n,
        final num n => n.toInt(),
        _ => int.tryParse('${row['mailbox_count'] ?? '0'}') ?? 0,
      },
      typeId: _nullableText(row['institution_type_id']),
      typeCode: _nullableText(row['institution_type_code']),
      typeName: _nullableText(row['institution_type_nom']),
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class InstitutionAgentCredential {
  const InstitutionAgentCredential({
    required this.email,
    this.password,
    this.directionCode,
    this.directionName,
    this.created = false,
    this.status = '',
  });

  final String email;
  final String? password;
  final String? directionCode;
  final String? directionName;
  final bool created;
  final String status;

  factory InstitutionAgentCredential.fromJson(Map<String, dynamic> json) {
    return InstitutionAgentCredential(
      email: '${json['email'] ?? ''}',
      password: _nullable(json['password'] ?? json['provisional_password']),
      directionCode: _nullable(json['direction_code']),
      directionName: _nullable(json['direction_nom'] ?? json['direction_name']),
      created: json['created'] == true,
      status: '${json['status'] ?? ''}',
    );
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}

class InstitutionActivationResult {
  const InstitutionActivationResult({
    required this.institutionId,
    required this.name,
    required this.slug,
    required this.actif,
    required this.emails,
    this.credentials = const [],
  });

  final String institutionId;
  final String name;
  final String slug;
  final bool actif;
  final List<InstitutionMailbox> emails;
  final List<InstitutionAgentCredential> credentials;

  factory InstitutionActivationResult.fromJson(Map<String, dynamic> json) {
    final rawEmails = json['emails'];
    final emails = <InstitutionMailbox>[];
    if (rawEmails is List) {
      for (final item in rawEmails) {
        if (item is Map<String, dynamic>) {
          emails.add(InstitutionMailbox.fromJson(item));
        } else if (item is Map) {
          emails.add(
            InstitutionMailbox.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final rawAccounts = json['accounts'] ?? json['credentials'];
    final credentials = <InstitutionAgentCredential>[];
    if (rawAccounts is List) {
      for (final item in rawAccounts) {
        if (item is Map<String, dynamic>) {
          credentials.add(InstitutionAgentCredential.fromJson(item));
        } else if (item is Map) {
          credentials.add(
            InstitutionAgentCredential.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }
    }

    return InstitutionActivationResult(
      institutionId: '${json['institution_id'] ?? ''}',
      name: '${json['nom'] ?? json['name'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      actif: json['actif'] == true || json['platform_enabled'] == true,
      emails: emails,
      credentials: credentials,
    );
  }

  InstitutionActivationResult copyWith({
    List<InstitutionAgentCredential>? credentials,
  }) {
    return InstitutionActivationResult(
      institutionId: institutionId,
      name: name,
      slug: slug,
      actif: actif,
      emails: emails,
      credentials: credentials ?? this.credentials,
    );
  }
}

/// Résultat du bouton « Créer / rafraîchir Auth » (pas de rotation MDP).
class ProvisionAccountsOutcome {
  const ProvisionAccountsOutcome({
    required this.ok,
    required this.message,
    this.result,
  });

  final bool ok;
  final String message;
  final InstitutionActivationResult? result;
}

/// Filtre local sur `institution_type_code`.
enum InstitutionTypeFilter {
  all,
  commune,
  policeRepublicaine,
  prefecture,
  ministere,
  cscgc,
  autres;

  String get label => switch (this) {
        all => 'Toutes',
        commune => 'Commune / Mairie',
        policeRepublicaine => 'Police républicaine',
        prefecture => 'Préfecture',
        ministere => 'Ministère',
        cscgc => 'CSCGC',
        autres => 'Autres',
      };

  bool matches(SuperAdminInstitution item) {
    final code = item.typeCodeUpper;
    return switch (this) {
      all => true,
      commune => item.isCommune,
      policeRepublicaine => item.isPoliceRepublicaine,
      prefecture => code == 'PREFECTURE',
      ministere => code == 'MINISTERE',
      cscgc => code == 'CSCGC',
      autres =>
        !item.isCommune &&
            !item.isPoliceRepublicaine &&
            code != 'PREFECTURE' &&
            code != 'MINISTERE' &&
            code != 'CSCGC',
    };
  }

  /// Ordre d’affichage des sections (aligné sur le tri RPC).
  static int sectionOrder(String? typeCode) {
    return switch ((typeCode ?? '').toUpperCase()) {
      'COMMUNE' || 'MAIRIE' => 1,
      'POLICE_REPUBLICAINE' => 2,
      'PREFECTURE' => 3,
      'MINISTERE' => 4,
      'CSCGC' => 5,
      _ => 9,
    };
  }

  static String sectionTitle(SuperAdminInstitution item) {
    final code = item.typeCodeUpper;
    if (code == 'COMMUNE' || code == 'MAIRIE') return 'Communes / Mairies';
    if (item.isPoliceRepublicaine) return 'Police républicaine';
    if (code == 'PREFECTURE') return 'Préfectures';
    if (code == 'MINISTERE') return 'Ministères';
    if (code == 'CSCGC') return 'CSCGC';
    return item.typeLabel == '—' ? 'Autres' : item.typeLabel;
  }
}
