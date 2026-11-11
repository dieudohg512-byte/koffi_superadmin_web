/// Fiche catalogue national (table `tourism_sites` / RPC `list_tourism_sites`).
class TourismSite {
  const TourismSite({
    required this.id,
    required this.slug,
    required this.name,
    required this.siteType,
    required this.summary,
    required this.latitude,
    required this.longitude,
    required this.recognitionRadiusM,
    required this.status,
    this.countryId,
    this.departmentId,
    this.departmentName,
    this.communeId,
    this.communeName,
    this.arrondissementLabel = '',
    this.quartierLabel = '',
    this.coverImageUrl,
    this.imageSourceUrl,
    this.imageCredit,
    this.publishedAt,
    this.updatedAt,
    this.avgRating,
    this.feedbackCount = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String siteType;
  final String summary;
  final String? countryId;
  final String? departmentId;
  final String? departmentName;
  final String? communeId;
  final String? communeName;
  final String arrondissementLabel;
  final String quartierLabel;
  final double latitude;
  final double longitude;
  final int recognitionRadiusM;
  final String? coverImageUrl;
  final String? imageSourceUrl;
  final String? imageCredit;
  final String status;
  final DateTime? publishedAt;
  final DateTime? updatedAt;
  final double? avgRating;
  final int feedbackCount;

  bool get isPublished => status == 'published';

  String get territoryLabel {
    final parts = <String>[
      if ((communeName ?? '').trim().isNotEmpty) communeName!.trim(),
      if ((departmentName ?? '').trim().isNotEmpty) departmentName!.trim(),
    ];
    return parts.isEmpty ? 'Territoire à renseigner' : parts.join(' · ');
  }

  factory TourismSite.fromJson(Map<String, dynamic> json) {
    return TourismSite(
      id: '${json['id']}',
      slug: '${json['slug'] ?? ''}',
      name: '${json['name'] ?? ''}',
      siteType: '${json['site_type'] ?? ''}',
      summary: '${json['summary'] ?? ''}',
      countryId: _strOrNull(json['country_id']),
      departmentId: _strOrNull(json['department_id']),
      departmentName: _strOrNull(json['department_name']),
      communeId: _strOrNull(json['commune_id']),
      communeName: _strOrNull(json['commune_name']),
      arrondissementLabel: '${json['arrondissement_label'] ?? ''}',
      quartierLabel: '${json['quartier_label'] ?? ''}',
      latitude: _toDouble(json['latitude']) ?? 0,
      longitude: _toDouble(json['longitude']) ?? 0,
      recognitionRadiusM: _toInt(json['recognition_radius_m']) ?? 250,
      coverImageUrl: _strOrNull(json['cover_image_url']),
      imageSourceUrl: _strOrNull(json['image_source_url']),
      imageCredit: _strOrNull(json['image_credit']),
      status: '${json['status'] ?? 'draft'}',
      publishedAt: _toDate(json['published_at']),
      updatedAt: _toDate(json['updated_at']),
      avgRating: _toDouble(json['avg_rating']),
      feedbackCount: _toInt(json['feedback_count']) ?? 0,
    );
  }

  static String? _strOrNull(Object? value) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int? _toInt(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static DateTime? _toDate(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse('$value');
  }
}
