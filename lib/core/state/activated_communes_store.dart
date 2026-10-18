import 'package:flutter/foundation.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';

/// Communes / mairies `platform_enabled` — partagé shell ↔ écran Institutions.
final activatedCommunesStore = ActivatedCommunesStore();

class ActivatedCommunesStore extends ChangeNotifier {
  List<SuperAdminInstitution> _items = const [];

  List<SuperAdminInstitution> get items => _items;

  int get count => _items.length;

  void updateFromInstitutions(List<SuperAdminInstitution> all) {
    final next = [
      for (final item in all)
        if (item.isCommune && item.platformEnabled) item,
    ]..sort((a, b) {
        final byDept = a.departmentLabel
            .toLowerCase()
            .compareTo(b.departmentLabel.toLowerCase());
        if (byDept != 0) return byDept;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    final same = next.length == _items.length &&
        List.generate(next.length, (i) => next[i].id == _items[i].id)
            .every((v) => v);
    if (same) return;
    _items = next;
    notifyListeners();
  }
}
