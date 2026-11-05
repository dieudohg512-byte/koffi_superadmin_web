/// Codes stables des modules institutionnels (table `institution_modules`).
abstract final class InstitutionModule {
  static const concerns = 'concerns';
  static const audiences = 'audiences';
  static const consultations = 'consultations';
  static const announcements = 'announcements';
  static const assemblies = 'assemblies';

  static const all = <String>[
    concerns,
    audiences,
    consultations,
    announcements,
    assemblies,
  ];

  static String label(String code) => switch (code) {
        concerns => 'Dossiers & signalements',
        audiences => 'Audiences',
        consultations => 'Consultations',
        announcements => 'Annonces',
        assemblies => 'Assemblées',
        _ => code,
      };

  static String hint(String code) => switch (code) {
        concerns => 'Kanban NGN, alertes, territoire, interop…',
        audiences => 'Demandes de rendez-vous citoyens.',
        consultations => 'Scrutins et propositions citoyennes.',
        announcements => 'Communications officielles.',
        assemblies => 'Sessions audio / visioconférence.',
        _ => '',
      };

  /// Pack par défaut selon le type ROI (miroir SQL).
  static List<String> defaultsForType(String? typeCode) {
    switch (typeCode?.trim().toUpperCase()) {
      case 'COMMUNE':
      case 'MAIRIE':
        return const [
          concerns,
          consultations,
          announcements,
          assemblies,
        ];
      case 'POLICE_REPUBLICAINE':
        return const [concerns, announcements];
      case 'PREFECTURE':
        return const [concerns, announcements];
      case 'MINISTERE':
      case 'CSCGC':
        return const [audiences];
      default:
        return const [audiences];
    }
  }
}
