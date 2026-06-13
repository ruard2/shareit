import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/zoek_spullen_scherm.dart';
import '../screens/mijn_spullen_scherm.dart';
import '../screens/profiel_scherm.dart';
import '../screens/nieuw_item_scherm.dart';

/// Responsive app-shell.
///
/// • Telefoon  → onderbalk (NavigationBar) + zwevende "+"-knop
/// • Desktop   → zijbalk (NavigationRail) met ShareIt-merk bovenaan
///
/// Eén navigatie voor de hele app: Home · Zoek · Mijn spullen · Profiel,
/// met een centrale "Nieuw item"-actie.
class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  // Telt mee als "verversingssleutel": bij ophogen herbouwt de actieve tab,
  // zodat lijsten verse data laden na het toevoegen van een item.
  int _refreshTick = 0;

  static const _destinations = [
    _Dest(Icons.home_outlined, Icons.home_rounded, 'Home'),
    _Dest(Icons.search_rounded, Icons.search_rounded, 'Zoek'),
    _Dest(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Mijn spullen'),
    _Dest(Icons.person_outline_rounded, Icons.person_rounded, 'Profiel'),
  ];

  Widget _pageFor(int i) {
    switch (i) {
      case 1:
        return ZoekScherm(key: ValueKey('zoek_$_refreshTick'));
      case 2:
        return MijnSpullenScherm(key: ValueKey('mijn_$_refreshTick'));
      case 3:
        return const ProfielScherm();
      case 0:
      default:
        return HomeScreen(key: ValueKey('home_$_refreshTick'));
    }
  }

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
  }

  Future<void> _nieuwItem() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NieuwItemScherm(onItemToegevoegd: (_) {}),
      ),
    );
    // Na toevoegen: ga naar "Mijn spullen" en forceer een verse load.
    if (!mounted) return;
    setState(() {
      _refreshTick++;
      _index = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.of(context).size.width >= 900;

    if (wide) return _desktop(cs);
    return _mobile(cs);
  }

  // ---- Mobiel: onderbalk + FAB -------------------------------------------
  Widget _mobile(ColorScheme cs) {
    return Scaffold(
      body: _pageFor(_index),
      floatingActionButton: FloatingActionButton(
        onPressed: _nieuwItem,
        tooltip: 'Nieuw item',
        elevation: 2,
        child: const Icon(Icons.add_rounded),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }

  // ---- Desktop: zijbalk ---------------------------------------------------
  Widget _desktop(ColorScheme cs) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: SizedBox(
              width: 230,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Merk
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.sync_alt_rounded,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Text('ShareIt',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  // Nieuw item
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FilledButton.icon(
                      onPressed: _nieuwItem,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Nieuw item'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Navigatie-items
                  for (int i = 0; i < _destinations.length; i++)
                    _RailTile(
                      dest: _destinations[i],
                      selected: _index == i,
                      onTap: () => _select(i),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 0.5, thickness: 0.5),
          Expanded(child: _pageFor(_index)),
        ],
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final IconData selected;
  final String label;
  const _Dest(this.icon, this.selected, this.label);
}

class _RailTile extends StatelessWidget {
  final _Dest dest;
  final bool selected;
  final VoidCallback onTap;
  const _RailTile(
      {required this.dest, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? cs.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(selected ? dest.selected : dest.icon,
                    size: 22,
                    color: selected ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(width: 14),
                Text(
                  dest.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? cs.primary : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
