import 'package:flutter/material.dart';

class InfoScherm extends StatelessWidget {
  const InfoScherm({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Over deze app')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Icon(Icons.handshake_outlined, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          Text(
            'Spullen Delen',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Samen meer doen met minder',
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          _section(
            context,
            icon: Icons.info_outline,
            title: 'Wat is Spullen Delen?',
            body:
                'Spullen Delen is een platform voor gesloten groepen — denk aan buren, vrienden of collega\'s — '
                'waarbinnen leden spullen met elkaar kunnen uitlenen of weggeven. '
                'De app maakt het eenvoudig om te zien wat er beschikbaar is, een leenverzoek in te dienen '
                'en de uitleen bij te houden.',
          ),
          const SizedBox(height: 20),

          _section(
            context,
            icon: Icons.lock_outline,
            title: 'Besloten gemeenschap',
            body:
                'De app werkt uitsluitend binnen uitgenodigde groepen. '
                'Nieuwe leden melden zich aan via een uitnodigingscode en worden vervolgens '
                'goedgekeurd door een groepsbeheerder. '
                'Zo blijft de kring vertrouwd en overzichtelijk.',
          ),
          const SizedBox(height: 20),

          _section(
            context,
            icon: Icons.swap_horiz_rounded,
            title: 'Hoe werkt uitlenen?',
            body:
                '1. Een lid plaatst een spulletje in de app met een foto en omschrijving.\n'
                '2. Andere leden zien het item en kunnen een leenverzoek sturen.\n'
                '3. De eigenaar keurt het verzoek goed en spreekt ophalen of bezorging af.\n'
                '4. Na gebruik markeert de lener het item als teruggebracht.',
          ),
          const SizedBox(height: 20),

          _section(
            context,
            icon: Icons.redeem_outlined,
            title: 'Gratis weggeven',
            body:
                'Naast uitlenen kun je spullen ook gratis aanbieden. '
                'Items die je niet meer nodig hebt, kunnen door een groepslid worden opgehaald — '
                'gratis en zonder verdere verplichtingen.',
          ),
          const SizedBox(height: 20),

          _section(
            context,
            icon: Icons.search_rounded,
            title: 'Iets nodig?',
            body:
                'Via de zoekfunctie vind je snel spullen binnen jouw groepen. '
                'Filter op categorie of toestand, bekijk de foto\'s en neem direct contact '
                'op met de eigenaar via de ingebouwde berichtenfunctie.',
          ),
          const SizedBox(height: 20),

          _section(
            context,
            icon: Icons.admin_panel_settings_outlined,
            title: 'Beheerders',
            body:
                'Elke groep heeft één of meer beheerders. Zij keuren nieuwe leden goed, '
                'beheren de groepssamenstelling en kunnen indien nodig items of verzoeken beheren. '
                'De supergebruiker beheert de gehele applicatie en kan nieuwe groepen aanmaken.',
          ),
          const SizedBox(height: 32),

          // Version / footer
          Text(
            'Versie 1.0  •  Spullen Delen',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: tt.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
