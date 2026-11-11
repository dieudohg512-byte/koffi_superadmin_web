/// Codes stables des modules institutionnels (table `institution_modules`).
abstract final class InstitutionModule {
  static const concerns = 'concerns';
  static const audiences = 'audiences';
  static const consultations = 'consultations';
  static const announcements = 'announcements';
  static const assemblies = 'assemblies';
  static const diasporaEconomique = 'diaspora_economique';
  static const protectionConsulaire = 'protection_consulaire';
  static const tourismExperience = 'tourism_experience';

  static const all = <String>[
    concerns,
    audiences,
    consultations,
    announcements,
    assemblies,
    diasporaEconomique,
    protectionConsulaire,
    tourismExperience,
  ];

  static String label(String code) => switch (code) {
        concerns => 'Dossiers & signalements',
        audiences => 'Audiences',
        consultations => 'Consultations',
        announcements => 'Annonces',
        assemblies => 'Assemblées',
        diasporaEconomique => 'Diaspora économique',
        protectionConsulaire => 'Protection consulaire',
        tourismExperience => 'Tourisme & expérience visiteurs',
        _ => code,
      };

  static String hint(String code) => switch (code) {
        concerns => 'Kanban NGN, alertes, territoire, interop…',
        audiences => 'Demandes de rendez-vous citoyens.',
        consultations => 'Scrutins et propositions citoyennes.',
        announcements => 'Communications officielles.',
        assemblies => 'Sessions audio / visioconférence.',
        diasporaEconomique => 'Projets et difficultés d’investissement diaspora.',
        protectionConsulaire => 'Signalements consulaires (Ambassades).',
        tourismExperience =>
          'Catalogue des sites, avis visiteurs, tableau de bord territorial.',
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
          audiences,
          diasporaEconomique,
          tourismExperience,
        ];
      case 'POLICE_REPUBLICAINE':
        return const [concerns, announcements];
      case 'PREFECTURE':
        return const [
          concerns,
          announcements,
          audiences,
          tourismExperience,
        ];
      case 'MINISTERE':
        return const [audiences, tourismExperience];
      case 'CSCGC':
        return const [audiences];
      case 'AMBASSADE':
        return const [protectionConsulaire];
      default:
        return const [audiences];
    }
  }
}
