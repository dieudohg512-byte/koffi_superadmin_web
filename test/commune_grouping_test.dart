import 'package:flutter_test/flutter_test.dart';
import 'package:koffi_superadmin_web/features/institutions/data/benin_commune_departments.dart';
import 'package:koffi_superadmin_web/features/institutions/domain/super_admin_institution.dart';

void main() {
  test('une commune sans type RPC est reconnue et rattachée au département', () {
    final cotonou = SuperAdminInstitution.fromRow({
      'id': '1',
      'nom': 'Commune de Cotonou',
      'slug': 'cotonou',
      'actif': true,
      'platform_enabled': true,
      'mailbox_count': 8,
    });

    expect(cotonou.isCommune, isTrue);
    expect(cotonou.typeCode, isNull);
    expect(beninCommuneDepartments['cotonou'], 'Littoral');
    expect(beninCommuneDepartments['abomey'], 'Zou');
    expect(beninCommuneDepartments['portonovo'], 'Ouémé');
  });
}
