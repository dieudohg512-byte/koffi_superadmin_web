class DepartmentRef {
  const DepartmentRef({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory DepartmentRef.fromRow(Map<String, dynamic> row) {
    final id = '${row['id'] ?? ''}'.trim();
    final name = (row['nom'] ?? row['name'] ?? row['label'] ?? id)
        .toString()
        .trim();
    return DepartmentRef(
      id: id,
      name: name.isEmpty ? id : name,
    );
  }
}
