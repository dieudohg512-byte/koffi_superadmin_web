class InstitutionMailbox {
  const InstitutionMailbox({
    required this.id,
    required this.institutionId,
    required this.directionId,
    required this.localPart,
    required this.email,
    this.createdAt,
  });

  final String id;
  final String institutionId;
  final String directionId;
  final String localPart;
  final String email;
  final DateTime? createdAt;

  factory InstitutionMailbox.fromJson(Map<String, dynamic> json) {
    return InstitutionMailbox(
      id: '${json['id'] ?? ''}',
      institutionId: '${json['institution_id'] ?? ''}',
      directionId: '${json['direction_id'] ?? ''}',
      localPart: '${json['local_part'] ?? ''}',
      email: '${json['email'] ?? ''}',
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }
}
