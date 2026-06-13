// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'mijn_spullen_scherm.dart';
import 'zoek_spullen_scherm.dart';
import 'groep_beheren_scherm.dart';
import 'instellingen_scherm.dart';
import 'info_scherm.dart';
import 'pending_actions_screen.dart';
import 'messages_screen.dart';
import 'beheer_groepsleden_scherm.dart';
import 'mijn_verzoeken_scherm.dart';
import '../models/item.dart';
import 'item_detail_scherm.dart';
import '../env.dart';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static String get _baseUrl => Env.apiBase;

  String gebruikersnaam = '';
  int beschikbaar       = 0;
  int mijnSpullen       = 0;
  int geleendDoorMij    = 0;
  bool isBeheerder      = false;
  List<dynamic> _myMemberships = [];

  int _pendingCount = 0;
  int _messageCount = 0;
  List<Item> _gratisItems = [];

  Timer? _countsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laadDashboardGegevens();
    _refreshCounts();
    _loadGratisItems();
    _countsTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => _refreshCounts());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countsTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCounts();
      _laadDashboardGegevens();
      _loadGratisItems();
    }
  }

  Future<void> _refreshCounts() async {
    await Future.wait([_loadPendingCount(), _loadMessageCount()]);
  }

  Future<void> _laadDashboardGegevens() async {
    try {
      final userResp = await ApiHelper.get('/gebruikers/mij');
      final dashResp = await ApiHelper.get('/gebruikers/dashboard');
      if (userResp.statusCode != 200 || dashResp.statusCode != 200) return;

      final userData = json.decode(userResp.body) as Map<String, dynamic>;
      final dashData = json.decode(dashResp.body) as Map<String, dynamic>;

      final adminOf   = (userData['admin_of_groups'] as List<dynamic>? ?? []);
      final globalRole = userData['role'] as String? ?? 'user';
      final memberships = (userData['memberships'] as List<dynamic>? ?? []);

      if (!mounted) return;
      setState(() {
        gebruikersnaam = userData['name'] as String? ?? '';
        _myMemberships = memberships;
        isBeheerder = adminOf.isNotEmpty || globalRole.toLowerCase() == 'superuser';
        beschikbaar  = dashData['beschikbaar'] as int? ?? 0;
        mijnSpullen  = dashData['mijn_spullen'] as int? ?? 0;
        geleendDoorMij = dashData['geleend_door_mij'] as int? ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _loadPendingCount() async {
    try {
      final resp = await ApiHelper.get('/notifications/count');
      if (resp.statusCode == 200) {
        int count = 0;
        try {
          final asJson = json.decode(resp.body);
          if (asJson is int) count = asJson;
          else if (asJson is Map && asJson['count'] is int) count = asJson['count'] as int;
          else if (asJson is num) count = asJson.toInt();
        } catch (_) {
          count = int.tryParse(resp.body.trim()) ?? 0;
        }
        if (!mounted) return;
        setState(() => _pendingCount = count < 0 ? 0 : count);
      }
    } catch (_) {}
  }

  Future<void> _loadMessageCount() async {
    try {
      final resp = await ApiHelper.get('/messages/count');
      if (resp.statusCode == 200) {
        int parsed = 0;
        try {
          final asJson = json.decode(resp.body);
          if (asJson is Map && asJson['count'] is int) parsed = asJson['count'] as int;
          else if (asJson is num) parsed = asJson.toInt();
        } catch (_) {
          parsed = int.tryParse(resp.body.trim()) ?? 0;
        }
        if (!mounted) return;
        setState(() => _messageCount = parsed);
      }
    } catch (_) {}
  }

  Future<void> _loadGratisItems() async {
    try {
      final resp = await ApiHelper.get('/items/');
      if (resp.statusCode == 200) {
        final all = json.decode(resp.body);
        if (all is List) {
          final items = all
              .whereType<Map<String, dynamic>>()
              .map((j) => Item.fromJson(j))
              .where((i) {
            final isGratis = i.leenkosten == null;
            final isVrij = i.status.toLowerCase() == 'free';
            return isGratis && isVrij;
          }).toList();
          if (!mounted) return;
          setState(() => _gratisItems = items);
        }
      }
    } catch (_) {}
  }

  void _openMijnGroep() {
    if (_myMemberships.length <= 1) {
      final gid = _myMemberships.isEmpty
          ? 0
          : (_myMemberships.first['group_id'] as int? ?? 0);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BeheerGroepsledenScherm(groupId: gid)),
      ).then((_) {
        _laadDashboardGegevens();
        _refreshCounts();
      });
    } else {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Kies een groep'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _myMemberships.length,
              itemBuilder: (ctx, i) {
                final grp  = _myMemberships[i] as Map<String, dynamic>;
                final name = grp['name'] as String? ?? 'Onbekend';
                final id   = grp['group_id'] as int? ?? 0;
                return ListTile(
                  title: Text(name),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BeheerGroepsledenScherm(groupId: id)),
                    ).then((_) {
                      _laadDashboardGegevens();
                      _refreshCounts();
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
    }
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final tt       = Theme.of(context).textTheme;
    final isTablet = Breakpoints.isTablet(context);
    final isLand   = Breakpoints.isLandscape(context);
    final hPad     = isTablet ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(cs, tt),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: () async {
          await _laadDashboardGegevens();
          await _refreshCounts();
          await _loadGratisItems();
        },
        child: _phoneLayout(cs, tt, hPad, isTablet),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ColorScheme cs, TextTheme tt) {
    return AppBar(
      automaticallyImplyLeading: false,
      title: gebruikersnaam.isEmpty
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hallo, $gebruikersnaam',
                  style: tt.titleLarge?.copyWith(color: cs.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
      actions: [
        // Notifications
        BadgeCount(
          count: _pendingCount,
          child: IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Meldingen',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PendingActionsScreen()),
            ).then((_) => _refreshCounts()),
          ),
        ),

        // Messages
        BadgeCount(
          count: _messageCount,
          child: IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: 'Berichten',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MessagesScreen()),
            ).then((_) => _refreshCounts()),
          ),
        ),

      ],
    );
  }

  // ---- Phone / portrait layout -------------------------------------------

  Widget _phoneLayout(ColorScheme cs, TextTheme tt, double hPad, bool isTablet) {
    return ResponsiveCenter(
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
        children: [
          // Stats row
          _statsRow(cs, tt, isTablet),
          const SizedBox(height: 24),

          // Gratis items — of een vriendelijke lege staat
          if (_gratisItems.isNotEmpty)
            _gratisItemsSection(cs, tt, hPad)
          else
            _emptyGratis(cs, tt),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _emptyGratis(ColorScheme cs, TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 14),
          Text('Nog niks beschikbaar',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Er staan nog geen gratis spullen in jouw groepen.\n'
            'Voeg zelf iets toe met de +-knop, of kijk later nog eens.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ---- Tablet landscape layout -------------------------------------------

  Widget _tabletLandscapeLayout(ColorScheme cs, TextTheme tt, double hPad) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: nav + stats
        Expanded(
          flex: 5,
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
            children: [
              _statsRow(cs, tt, true),
              const SizedBox(height: 20),
              _navSection(cs, tt),
            ],
          ),
        ),

        // Right column: gratis items
        if (_gratisItems.isNotEmpty)
          Expanded(
            flex: 4,
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
              children: [_gratisItemsSection(cs, tt, hPad)],
            ),
          ),
      ],
    );
  }

  // ---- Reusable sections --------------------------------------------------

  Widget _statsRow(ColorScheme cs, TextTheme tt, bool isTablet) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Beschikbaar',
            value: '$beschikbaar',
            icon: Icons.inventory_2_outlined,
            color: cs.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'Mijn spullen',
            value: '$mijnSpullen',
            icon: Icons.widgets_outlined,
            color: AppleColors.systemGreen,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: 'Geleend',
            value: '$geleendDoorMij',
            icon: Icons.swap_horiz_rounded,
            color: AppleColors.systemOrange,
          ),
        ),
      ],
    );
  }

  Widget _navSection(ColorScheme cs, TextTheme tt) {
    return IosSection(
      header: 'Menu',
      margin: EdgeInsets.zero,
      children: [
        // Zoek
        IosListTile(
          leading: IosIconContainer(
            icon: Icons.search_rounded,
            color: cs.primary,
          ),
          title: const Text('Zoek spullen'),
          subtitle: const Text('Bekijk beschikbare items'),
          showChevron: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ZoekScherm()),
          ).then((_) => _laadDashboardGegevens()),
        ),

        // Mijn spullen
        IosListTile(
          leading: IosIconContainer(
            icon: Icons.inventory_2_outlined,
            color: AppleColors.systemGreen,
          ),
          title: const Text('Mijn spullen'),
          subtitle: const Text('Beheer wat je deelt'),
          showChevron: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MijnSpullenScherm()),
          ).then((_) => _laadDashboardGegevens()),
        ),

        // Mijn verzoeken
        IosListTile(
          leading: IosIconContainer(
            icon: Icons.assignment_outlined,
            color: AppleColors.systemOrange,
          ),
          title: const Text('Mijn verzoeken'),
          subtitle: const Text('Status van je leenverzoeken'),
          showChevron: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MijnVerzoekenScherm()),
          ),
        ),

        // Groep (leden) / Groep beheren (admin)
        if (!isBeheerder)
          IosListTile(
            leading: IosIconContainer(
              icon: Icons.group_outlined,
              color: AppleColors.systemGray,
            ),
            title: const Text('Mijn groep'),
            subtitle: const Text('Bekijk groepsleden'),
            showChevron: true,
            onTap: _openMijnGroep,
          ),

        if (isBeheerder)
          IosListTile(
            leading: IosIconContainer(
              icon: Icons.admin_panel_settings_outlined,
              color: AppleColors.systemRed,
            ),
            title: const Text('Groep beheren'),
            subtitle: const Text('Leden, verzoeken & instellingen'),
            showChevron: true,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroepBeherenScherm()),
            ).then((_) {
              _laadDashboardGegevens();
              _refreshCounts();
            }),
          ),

        // Info
        IosListTile(
          leading: IosIconContainer(
            icon: Icons.info_outline_rounded,
            color: AppleColors.systemGray,
          ),
          title: const Text('Info'),
          subtitle: const Text('Over de app'),
          showChevron: true,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InfoScherm()),
          ).then((_) => _laadDashboardGegevens()),
        ),
      ],
    );
  }

  Widget _gratisItemsSection(ColorScheme cs, TextTheme tt, double hPad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Gratis beschikbaar',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          height: 200,
          child: PageView.builder(
            itemCount: _gratisItems.length,
            controller: PageController(viewportFraction: 0.75),
            itemBuilder: (ctx, i) {
              final item = _gratisItems[i];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () async {
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScherm(item: item),
                      ),
                    );
                    if (changed == true) {
                      await _loadGratisItems();
                      await _refreshCounts();
                      await _laadDashboardGegevens();
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: cs.surface,
                      child: item.imagePath != null
                          // ── Met afbeelding: foto + naam-overlay onderaan ──
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  ApiHelper.resolveImageUrl(item.imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.broken_image_outlined,
                                    size: 40,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                // Gradient + naam
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withValues(alpha: 0.65),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    padding: const EdgeInsets.fromLTRB(
                                        10, 20, 10, 8),
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        shadows: [
                                          Shadow(
                                            blurRadius: 4,
                                            color: Colors.black54,
                                          )
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          // ── Zonder afbeelding: icoon + naam ──
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2_outlined,
                                    size: 40, color: cs.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: Text(
                                    item.name,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
