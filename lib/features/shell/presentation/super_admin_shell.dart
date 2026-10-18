import 'package:flutter/material.dart';
import 'package:koffi_superadmin_web/core/state/activated_communes_store.dart';
import 'package:koffi_superadmin_web/core/theme/app_theme.dart';
import 'package:koffi_superadmin_web/features/institutions/presentation/activated_communes_page.dart';
import 'package:koffi_superadmin_web/features/institutions/presentation/institutions_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final extended = MediaQuery.sizeOf(context).width >= 1100;

    return ListenableBuilder(
      listenable: activatedCommunesStore,
      builder: (context, _) {
        final activeCount = activatedCommunesStore.count;
        final destinations = [
          const NavigationRailDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(Icons.account_balance),
            label: Text('Institutions'),
          ),
          NavigationRailDestination(
            icon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.location_city_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: activeCount > 0,
              label: Text('$activeCount'),
              child: const Icon(Icons.location_city),
            ),
            label: Text('Communes actives ($activeCount)'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: Text('Éditeur ROI'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: Icon(Icons.admin_panel_settings),
            label: Text('Comptes Super-Admin'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: Text('Monitoring IA'),
          ),
        ];

        const titles = [
          'Institutions',
          'Communes actives',
          'Éditeur ROI',
          'Comptes Super-Admin',
          'Monitoring IA',
        ];

        final compact = MediaQuery.sizeOf(context).width < 840;
        if (compact) {
          return Scaffold(
            appBar: AppBar(
              title: Text(titles[_index]),
              actions: [
                IconButton(
                  tooltip: 'Déconnexion',
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  icon: const Icon(Icons.logout),
                ),
              ],
            ),
            drawer: Drawer(
              child: SafeArea(
                child: Builder(
                  builder: (drawerContext) {
                    return ListView(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.shield_outlined,
                            color: AppTheme.accent,
                          ),
                          title: const Text(
                            'Koffi Super Admin',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Divider(),
                        for (var i = 0; i < titles.length; i++)
                          ListTile(
                            selected: _index == i,
                            leading: destinations[i].icon,
                            title: Text(titles[i] == 'Communes actives'
                                ? 'Communes actives ($activeCount)'
                                : titles[i]),
                            onTap: () {
                              setState(() => _index = i);
                              Navigator.pop(drawerContext);
                            },
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            body: _buildBody(),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                extended: extended,
                minExtendedWidth: 220,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                  child: Column(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.accent),
                      const SizedBox(height: 6),
                      Text(
                        extended ? 'Koffi Super Admin' : 'Koffi',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppTheme.ink,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                destinations: destinations,
                trailing: Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: 'Déconnexion',
                        onPressed: () =>
                            Supabase.instance.client.auth.signOut(),
                        icon: const Icon(Icons.logout, color: AppTheme.muted),
                      ),
                    ),
                  ),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppTheme.border,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AppTheme.surface,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppTheme.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              titles[_index],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                            const Spacer(),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_index) {
      0 => const InstitutionsPage(),
      1 => const ActivatedCommunesPage(),
      2 => const _PlaceholderPane(
          title: 'Éditeur ROI',
          subtitle: 'Édition des textes ROI — à venir.',
        ),
      3 => const _PlaceholderPane(
          title: 'Comptes Super-Admin',
          subtitle: 'Gestion des comptes Super-Admin — à venir.',
        ),
      _ => const _PlaceholderPane(
          title: 'Monitoring IA',
          subtitle: 'Suivi des usages et coûts IA — à venir.',
        ),
    };
  }
}

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.construction_outlined,
            size: 36,
            color: AppTheme.muted,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
