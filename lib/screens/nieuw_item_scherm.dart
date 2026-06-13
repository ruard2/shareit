import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/item.dart';
import '../models/group.dart';
import '../env.dart';
import '../utils/api_helper.dart';

class NieuwItemScherm extends StatefulWidget {
  final Function(Item) onItemToegevoegd;
  final Item? bestaandItem;

  const NieuwItemScherm({
    super.key,
    required this.onItemToegevoegd,
    this.bestaandItem,
  });

  @override
  State<NieuwItemScherm> createState() => _NieuwItemSchermState();
}

class _NieuwItemSchermState extends State<NieuwItemScherm> {
  final _naamController        = TextEditingController();
  final _infoController        = TextEditingController();
  final _leenkostenController  = TextEditingController();
  final _maxDagenController    = TextEditingController();

  /// Nieuw gekozen foto (nog niet geüpload). XFile werkt op web én native.
  XFile? _newLocalImage;

  /// Pad/URL van **bestaande** foto (zoals geleverd door backend)
  String? _existingImagePath;

  int? _userId;
  String? _sessionId;
  bool _isPickup = false;

  // Feature 5: categorie & toestand
  String? _category;
  String? _condition;

  static const _categories = [
    'Gereedschap', 'Keuken', 'Sport', 'Kleding', 'Elektronica',
    'Meubels', 'Boeken', 'Speelgoed', 'Tuin', 'Overig',
  ];
  static const _conditions = ['Nieuw', 'Goed', 'Redelijk', 'Versleten'];

  List<Group> _groups = [];
  Set<int> _selectedGroupIds = {};

  static String get _baseUrl => Env.apiBase;

  @override
  void initState() {
    super.initState();
    _initSessionAndData();
    if (widget.bestaandItem != null) {
      final item = widget.bestaandItem!;
      _naamController.text       = item.name;
      _infoController.text       = item.info ?? '';
      _leenkostenController.text = item.leenkosten?.toString() ?? '';
      _maxDagenController.text   = item.maxBorrowDays?.toString() ?? '';
      _selectedGroupIds = item.availableGroupIds.toSet();
      _isPickup = item.leenkosten == null;
      _category = item.category;
      _condition = item.condition;

      // Sla bestaande foto-URL/path op om te kunnen tonen
      _existingImagePath = item.imagePath;
    }
  }

  Future<void> _initSessionAndData() async {
    final prefs = await SharedPreferences.getInstance();
    final sid = prefs.getString('session_id');
    setState(() => _sessionId = sid);

    final resp = await ApiHelper.get('/gebruikers/mij');
    if (resp.statusCode == 200) {
      final me = json.decode(resp.body) as Map<String, dynamic>;
      setState(() => _userId = me['id'] as int);
      await _fetchGroups();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sessie verlopen, log opnieuw in')));
      }
    }
  }

  Future<void> _fetchGroups() async {
    final resp = await ApiHelper.get('/groepen/mijn');
    if (resp.statusCode == 200) {
      final List data = json.decode(resp.body) as List;
      setState(() {
        _groups = data
            .map<Group>((j) => Group.fromJson(j as Map<String, dynamic>))
            .toList();
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kon groepen niet laden')));
      }
    }
  }

  Future<void> _selecteerFoto() async {
    ImageSource? source;

    if (kIsWeb) {
      // Op web is camera niet beschikbaar via image_picker — ga direct naar bestandskiezer
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galerij'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }

    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked != null) {
      setState(() => _newLocalImage = picked);
    }
  }

  Future<void> _opslaan() async {
    final naam = _naamController.text.trim();
    if (naam.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Naam is verplicht')));
      return;
    }

    // Bij gratis ophalen: foto verplicht. Dat mag óf een bestaande foto zijn, óf een nieuwe.
    final hasAnyPhoto = (_newLocalImage != null) || (_existingImagePath != null);
    if (_isPickup && !hasAnyPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto is verplicht bij gratis ophalen')));
      return;
    }

    if (_userId == null || _sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gebruiker of sessie niet gevonden')));
      return;
    }

    // Valideer leenkosten (moet een getal zijn, bv. 2.50)
    double? leenkosten;
    if (!_isPickup && _leenkostenController.text.trim().isNotEmpty) {
      leenkosten = double.tryParse(
          _leenkostenController.text.trim().replaceAll(',', '.'));
      if (leenkosten == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Leenkosten moet een getal zijn, bv. 2.50. '
                'Gebruik het notitieveld voor een toelichting.')));
        return;
      }
    }

    // Valideer max. uitleentermijn (moet een heel getal zijn)
    int? maxDagen;
    if (_maxDagenController.text.trim().isNotEmpty) {
      maxDagen = int.tryParse(_maxDagenController.text.trim());
      if (maxDagen == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Max. uitleentermijn moet een heel getal zijn, bv. 7.')));
        return;
      }
    }

    final Map<String, dynamic> jsonData = {
      'name': naam,
      'info': _infoController.text.trim().isEmpty
          ? null
          : _infoController.text.trim(),
      'owner_id': _userId,
      'available_group_ids': _selectedGroupIds.toList(),
      if (!_isPickup) 'leenkosten': leenkosten ?? 0,
      // Bij gratis ophalen laten we 'leenkosten' weg
      if (_category != null) 'category': _category,
      if (_condition != null) 'condition': _condition,
      if (maxDagen != null) 'max_borrow_days': maxDagen,
    };

    final isNieuw = widget.bestaandItem == null;
    final uri = isNieuw
        ? Uri.parse('${Env.apiBase}/items/')
        : Uri.parse('${Env.apiBase}/items/${widget.bestaandItem!.id}');
    final authHeaders = await ApiHelper.getHeaders();
    final req = http.Request(isNieuw ? 'POST' : 'PUT', uri)
      ..headers.addAll(authHeaders)
      ..body = json.encode(jsonData);

    final streamed = await req.send();
    if (streamed.statusCode != 200 && streamed.statusCode != 201) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Fout bij opslaan')));
      return;
    }

    var body = await streamed.stream.bytesToString();
    Item item = Item.fromJson(json.decode(body));

    // Alleen uploaden als er een nieuwe lokale foto gekozen is
    if (_newLocalImage != null) {
      final bytes = await _newLocalImage!.readAsBytes();
      final filename = _newLocalImage!.name.isNotEmpty
          ? _newLocalImage!.name
          : 'image.jpg';
      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('${Env.apiBase}/items/${item.id}/upload-photo'),
      )
        ..headers.addAll(authHeaders)
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ));

      final uploadResp = await uploadReq.send();
      if (uploadResp.statusCode == 200) {
        body = await uploadResp.stream.bytesToString();
        item = Item.fromJson(json.decode(body));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto-upload mislukt')),
        );
      }
    }

    widget.onItemToegevoegd(item);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildImagePreview() {
    // Prioriteit: eerst nieuwe lokale foto tonen, anders bestaande server-foto
    if (_newLocalImage != null) {
      // Op web: XFile.path is een blob-URL — gebruik Image.network
      // Op native: gebruik Image.file voor lokale bestanden
      final preview = kIsWeb
          ? Image.network(_newLocalImage!.path, height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 60))
          : Image.file(File(_newLocalImage!.path), height: 150,
              fit: BoxFit.cover);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _selecteerFoto,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Wijzig foto'),
          ),
        ],
      );
    }

    if (_existingImagePath != null && _existingImagePath!.isNotEmpty) {
      final isNetwork = ApiHelper.isNetworkImage(_existingImagePath!);
      final preview = (isNetwork || kIsWeb)
          ? Image.network(
              isNetwork
                  ? ApiHelper.resolveImageUrl(_existingImagePath!)
                  : _existingImagePath!,
              height: 150, fit: BoxFit.cover)
          : Image.file(File(_existingImagePath!), height: 150,
              fit: BoxFit.cover);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          preview,
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _selecteerFoto,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Wijzig foto'),
          ),
        ],
      );
    }

    // Geen foto aanwezig
    return TextButton.icon(
      onPressed: _selecteerFoto,
      icon: const Icon(Icons.camera_alt),
      label: const Text('Voeg foto toe'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bestaandItem != null
            ? 'Item bewerken'
            : 'Nieuw item toevoegen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Item beschikbaar om:'),
                Text(_isPickup ? 'Gratis ophalen' : 'Uitlenen'),
                Switch(
                  value: _isPickup,
                  onChanged: (v) => setState(() => _isPickup = v),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _naamController,
              decoration: const InputDecoration(labelText: 'Naam (verplicht)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _infoController,
              decoration: const InputDecoration(labelText: 'Extra info'),
            ),
            const SizedBox(height: 10),
            if (!_isPickup) ...[
              TextField(
                controller: _leenkostenController,
                decoration: const InputDecoration(
                  labelText: 'Leenkosten (optioneel)',
                  hintText: 'bv. 2.50',
                  prefixIcon: Icon(Icons.euro_outlined),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Max uitleentermijn
            TextField(
              controller: _maxDagenController,
              decoration: const InputDecoration(
                labelText: 'Max. uitleentermijn in dagen (optioneel)',
                hintText: 'bv. 7',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),

            // Feature 5: Categorie
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Categorie (optioneel)'),
              value: _category,
              items: [
                const DropdownMenuItem(value: null, child: Text('— geen —')),
                ..._categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 10),

            // Feature 5: Toestand
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Toestand (optioneel)'),
              value: _condition,
              items: [
                const DropdownMenuItem(value: null, child: Text('— onbekend —')),
                ..._conditions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _condition = v),
            ),
            const SizedBox(height: 16),

            const Text('Beschikbaar voor groepen:'),
            CheckboxListTile(
              title: const Text('Alle groepen'),
              value: _selectedGroupIds.isEmpty,
              onChanged: (yes) {
                if (yes == true) setState(() => _selectedGroupIds.clear());
              },
            ),
            const Divider(),
            ..._groups.map(
              (g) => CheckboxListTile(
                title: Text(g.name),
                value: _selectedGroupIds.contains(g.id),
                onChanged: (yes) {
                  setState(() {
                    if (yes == true) {
                      _selectedGroupIds.add(g.id);
                    } else {
                      _selectedGroupIds.remove(g.id);
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Foto-onderdeel (bestaande of nieuwe foto tonen + wijzigen)
            _buildImagePreview(),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _opslaan,
              child: const Text('Opslaan'),
            ),
          ],
        ),
      ),
    );
  }
}
