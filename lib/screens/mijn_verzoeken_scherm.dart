// lib/screens/mijn_verzoeken_scherm.dart
// Feature 4: Status van eigen leenverzoeken
import 'package:flutter/material.dart';
import 'dart:convert';
import '../utils/api_helper.dart';
import '../widgets/design_system.dart';
import '../theme.dart';

class MijnVerzoekenScherm extends StatefulWidget {
  const MijnVerzoekenScherm({super.key});

  @override
  State<MijnVerzoekenScherm> createState() => _MijnVerzoekenSchermState();
}

class _MijnVerzoekenSchermState extends State<MijnVerzoekenScherm> {
  List<Map<String, dynamic>> _verzoeken = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _laadVerzoeken();
  }

  Future<void> _laadVerzoeken() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final resp = await ApiHelper.get('/requests/mine');
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List<dynamic>;
        setState(() {
          _verzoeken = list.cast<Map<String, dynamic>>();
          _loading   = false;
        });
      } else {
        setState(() {
          _error   = 'Kon verzoeken niet laden (${resp.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error   = 'Fout: $e';
        _loading = false;
      });
    }
  }

  // ---- helpers -------------------------------------------------------------

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':          return 'In behandeling';
      case 'approved':         return 'Goedgekeurd';
      case 'denied':           return 'Afgewezen';
      case 'return_requested': return 'Terugbrengen gevraagd';
      case 'returned':         return 'Teruggegeven';
      default:                 return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'approved':         return AppleColors.systemGreen;
      case 'denied':           return AppleColors.systemRed;
      case 'returned':         return AppleColors.systemGray;
      case 'return_requested': return AppleColors.systemOrange;
      default:                 return AppleColors.systemBlue;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'approved':         return Icons.check_circle_outline_rounded;
      case 'denied':           return Icons.cancel_outlined;
      case 'returned':         return Icons.assignment_returned_outlined;
      case 'return_requested': return Icons.undo_rounded;
      default:                 return Icons.hourglass_empty_rounded;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}-${d.month}-${d.year}';
  }

  // ---- actions -------------------------------------------------------------

  Future<void> _annuleerVerzoek(int reqId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verzoek annuleren'),
        content: const Text('Weet je zeker dat je dit leenverzoek wil annuleren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nee'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Ja, annuleer',
                style: TextStyle(color: AppleColors.systemRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final resp = await ApiHelper.delete('/requests/$reqId');
    if (resp.statusCode == 204) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verzoek geannuleerd')),
      );
      _laadVerzoeken();
    } else {
      String msg = 'Annuleren mislukt (${resp.statusCode})';
      try {
        final body = jsonDecode(resp.body);
        msg = body['detail'] ?? msg;
      } catch (_) {}
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final isTablet = Breakpoints.isTablet(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mijn verzoeken'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Vernieuwen',
            onPressed: _laadVerzoeken,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(cs)
              : _verzoeken.isEmpty
                  ? _buildEmpty(cs)
                  : RefreshIndicator(
                      color: cs.primary,
                      onRefresh: _laadVerzoeken,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: isTablet ? 640 : double.infinity),
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 0,
                              vertical: 12,
                            ),
                            itemCount: _verzoeken.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (ctx, i) =>
                                _buildCard(ctx, _verzoeken[i], cs),
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildCard(
      BuildContext ctx, Map<String, dynamic> v, ColorScheme cs) {
    final tt         = Theme.of(ctx).textTheme;
    final status     = v['status'] as String? ?? 'pending';
    final itemName   = v['item_name'] as String? ?? 'Onbekend item';
    final createdAt  = v['created_at'] as String?;
    final returnBy   = v['return_by'] as String?;
    final message    = v['message'] as String?;
    final reqId      = v['id'] as int?;
    final statusColor = _statusColor(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_statusIcon(status), color: statusColor, size: 22),
              ),

              const SizedBox(width: 14),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Item name + status badge on same row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemName,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusBadge(status, statusColor),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Date created
                    if (createdAt != null)
                      _metaRow(
                        Icons.calendar_today_outlined,
                        'Aangevraagd: ${_fmtDate(createdAt)}',
                        cs.onSurfaceVariant,
                      ),

                    // Return-by date
                    if (returnBy != null) ...[
                      const SizedBox(height: 3),
                      _metaRow(
                        Icons.event_available_outlined,
                        'Terugbrengen voor: ${_fmtDate(returnBy)}',
                        AppleColors.systemOrange,
                      ),
                    ],

                    // Message / note
                    if (message != null && message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          message,
                          style: tt.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],

                    // Cancel button — only for pending requests
                    if (status == 'pending' && reqId != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _annuleerVerzoek(reqId),
                          icon: Icon(Icons.cancel_outlined,
                              size: 16, color: AppleColors.systemRed),
                          label: Text(
                            'Verzoek annuleren',
                            style: TextStyle(color: AppleColors.systemRed),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color: AppleColors.systemRed.withValues(alpha: 0.4)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppleColors.systemRed),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppleFilledButton(
              label: 'Opnieuw proberen',
              onPressed: _laadVerzoeken,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Geen verzoeken',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Je hebt nog geen leenverzoeken gedaan.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
