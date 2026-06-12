// lib/screens/start_scherm.dart
import 'package:flutter/material.dart';
import '../widgets/design_system.dart';

class StartScherm extends StatelessWidget {
  const StartScherm({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;
    final isTablet = Breakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 480 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 48 : 32,
              ),
              child: Column(
                children: [
                  // ---- Spacer + Logo area ----
                  const Spacer(flex: 3),

                  // App icon placeholder
                  Container(
                    width: isTablet ? 120 : 96,
                    height: isTablet ? 120 : 96,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(isTablet ? 28 : 22),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.people_alt_rounded,
                      color: Colors.white,
                      size: isTablet ? 60 : 48,
                    ),
                  ),

                  SizedBox(height: isTablet ? 32 : 24),

                  // App name
                  Text(
                    'Spullen Delen',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: cs.onSurface,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Deel spullen gratis met je vrienden\nen buren in een veilige groep.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(flex: 3),

                  // ---- Buttons ----
                  AppleFilledButton(
                    label: 'Nieuw account aanmaken',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/registratie'),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Inloggen',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
