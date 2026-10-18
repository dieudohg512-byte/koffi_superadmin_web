/// Ligne renvoyée par `list_institution_functional_emails`.
class InstitutionFunctionalEmail {
  const InstitutionFunctionalEmail({
    required this.directionId,
    this.directionCode,
    required this.directionNom,
    required this.email,
    this.localPart,
  });

  final String directionId;
  final String? directionCode;
  final String directionNom;
  final String email;
  final String? localPart;

  /// « Nom (SIGLE) ». Le nom en base n'inclut pas le code ; à défaut, le
  /// local-part de la boîte (cab, se, dst…) sert de sigle.
  String get labelWithSigle {
    final sigle =
        (directionCode ?? localPart)?.trim().toUpperCase() ?? '';
    if (sigle.isEmpty) return directionNom;
    if (directionNom.contains('($sigle)')) return directionNom;
    return '$directionNom ($sigle)';
  }

  factory InstitutionFunctionalEmail.fromRow(Map<String, dynamic> row) {
    return InstitutionFunctionalEmail(
      directionId: '${row['direction_id'] ?? ''}',
      directionCode: _nullableText(row['direction_code']),
      directionNom: _nullableText(row['direction_nom']) ?? '—',
      email: '${row['email'] ?? ''}',
      localPart: _nullableText(row['local_part']),
    );
  }

  static String? _nullableText(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
