import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../models/item.dart';
import '../utils/api_helper.dart';
import '../env.dart';

class ItemDetailScherm extends StatefulWidget {
  final Item item;
  static String get _baseUrl => Env.apiBase;

  const ItemDetailScherm({Key? key, required this.item}) : super(key: key);

  @override
  State<ItemDetailScherm> createState() => _ItemDetailSchermState();
}

class _ItemDetailSchermState extends State<ItemDetailScherm> {
  DateTime? _returnBy; // Feature 1: gewenste terugbrengdatum
  bool _loading = false;

  Future<void> _pickReturnDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Wanneer breng je het terug?',
    );
    if (picked != null) setState(() => _returnBy = picked);
  }

  Future<void> _doRequest() async {
    setState(() => _loading = true);
    final item = widget.item;
    final bool isFreePickup = item.leenkosten == null;

    try {
      late http.Response resp;
      if (isFreePickup) {
        // Gratis ophalen: geen return_by nodig
        resp = await ApiHelper.post('/items/${item.id}/reserve', {});
      } else {
        // Lenen: stuur return_by mee als opgegeven
        final body = <String, dynamic>{};
        if (_returnBy != null) {
          body['return_by'] = _returnBy!.toIso8601String();
        }
        resp = await ApiHelper.post('/items/${item.id}/borrow', body);
      }

      if (!mounted) return;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFreePickup
                ? 'Afhaalverzoek verstuurd voor ${item.name}'
                : 'Leenverzoek verstuurd voor ${item.name}'),
          ),
        );
      } else {
        // Stay on screen so the error is visible
        String detail;
        try {
          final err = jsonDecode(resp.body) as Map<String, dynamic>;
          detail = err['detail']?.toString() ?? resp.statusCode.toString();
        } catch (_) {
          detail = resp.statusCode.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(isFreePickup
                ? 'Kon afhaalverzoek niet versturen: $detail'
                : 'Kon niet lenen: $detail'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    Widget? imageWidget;
    if (item.imagePath != null && item.imagePath!.isNotEmpty) {
      if (ApiHelper.isNetworkImage(item.imagePath!)) {
        imageWidget = Image.network(
          ApiHelper.resolveImageUrl(item.imagePath!),
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else if (!kIsWeb) {
        imageWidget = Image.file(
          File(item.imagePath!),
          width: double.infinity,
          height: 200,
          fit: BoxFit.cover,
        );
      }
    }

    final bool isFreePickup = item.leenkosten == null;

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageWidget != null) ...[
              imageWidget,
              const SizedBox(height: 16),
            ],
            Text('Naam: ${item.name}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            if (item.info != null) ...[
              Text('Info: ${item.info!}'),
              const SizedBox(height: 8),
            ],
            if (!isFreePickup) ...[
              Text('Leenkosten: €${item.leenkosten!}'),
              const SizedBox(height: 8),
            ],
            // Feature 2: eigenaar
            if (item.ownerName != null) ...[
              Text('Eigenaar: ${item.ownerName!}',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
            ],
            // Feature 5: categorie & toestand
            if (item.category != null) ...[
              Text('Categorie: ${item.category!}',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
            ],
            if (item.condition != null) ...[
              Text('Toestand: ${item.condition!}',
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
            ],
            // Feature 1: terugbrengdatum picker (alleen bij lenen)
            if (!isFreePickup) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.event_available, size: 18, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _returnBy == null
                          ? 'Terugbrengdatum (optioneel)'
                          : 'Terugbrengen op: ${_returnBy!.day}-${_returnBy!.month}-${_returnBy!.year}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickReturnDate,
                    child: Text(_returnBy == null ? 'Kies datum' : 'Wijzig'),
                  ),
                ],
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _doRequest,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isFreePickup ? 'Afhalen' : 'Leen'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
