class TourismSuperAdminOverview {
  const TourismSuperAdminOverview({
    required this.institutionsEnabled,
    required this.institutionsMairie,
    required this.institutionsPrefecture,
    required this.institutionsMinistere,
    required this.sitesTotal,
    required this.sitesPublished,
    required this.sitesDraft,
    required this.communesCovered,
    required this.feedbacksTotal,
    required this.issuesTotal,
  });

  final int institutionsEnabled;
  final int institutionsMairie;
  final int institutionsPrefecture;
  final int institutionsMinistere;
  final int sitesTotal;
  final int sitesPublished;
  final int sitesDraft;
  final int communesCovered;
  final int feedbacksTotal;
  final int issuesTotal;

  factory TourismSuperAdminOverview.fromJson(Map<String, dynamic> json) {
    int asInt(Object? value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return TourismSuperAdminOverview(
      institutionsEnabled: asInt(json['institutions_enabled']),
      institutionsMairie: asInt(json['institutions_mairie']),
      institutionsPrefecture: asInt(json['institutions_prefecture']),
      institutionsMinistere: asInt(json['institutions_ministere']),
      sitesTotal: asInt(json['sites_total']),
      sitesPublished: asInt(json['sites_published']),
      sitesDraft: asInt(json['sites_draft']),
      communesCovered: asInt(json['communes_covered']),
      feedbacksTotal: asInt(json['feedbacks_total']),
      issuesTotal: asInt(json['issues_total']),
    );
  }
}

class TourismModuleInstitution {
  const TourismModuleInstitution({
    required this.institutionId,
    required this.institutionName,
    required this.institutionType,
    required this.enabled,
    this.institutionTypeLabel,
    this.communeName,
    this.departmentName,
  });

  final String institutionId;
  final String institutionName;
  final String institutionType;
  final String? institutionTypeLabel;
  final bool enabled;
  final String? communeName;
  final String? departmentName;

  String get territoryLabel {
    final parts = <String>[
      if ((communeName ?? '').trim().isNotEmpty) communeName!.trim(),
      if ((departmentName ?? '').trim().isNotEmpty) departmentName!.trim(),
    ];
    return parts.isEmpty ? 'National / multi' : parts.join(' · ');
  }

  factory TourismModuleInstitution.fromJson(Map<String, dynamic> json) {
    String? asStr(Object? value) {
      final text = '$value'.trim();
      if (text.isEmpty || text == 'null') return null;
      return text;
    }

    return TourismModuleInstitution(
      institutionId: '${json['institution_id']}',
      institutionName: '${json['institution_name'] ?? ''}',
      institutionType: '${json['institution_type'] ?? ''}',
      institutionTypeLabel: asStr(json['institution_type_label']),
      enabled: json['enabled'] == true,
      communeName: asStr(json['commune_name']),
      departmentName: asStr(json['department_name']),
    );
  }
}
