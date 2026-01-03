import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:flutter/services.dart';

import 'api/spots_api.dart';
import 'location_picker_screen.dart';

enum SpotLocationSource { none, currentLocation, manual }

class AddSpotScreen extends ConsumerStatefulWidget {
  const AddSpotScreen({super.key});

  @override
  ConsumerState<AddSpotScreen> createState() => _AddSpotScreenState();
}

// Add top-level helper for service icons (so it can be used by nested widgets too)
String? serviceIconAssetForLabel(String label) {
  final lower = label.toLowerCase().trim();

  // Normalize underscores/hyphens
  final norm = lower.replaceAll('‑', '-');

  // Backend keys support (english / snake_case)
  if (norm == 'animals' || norm.contains('animali')) {
    return 'assets/icons/markers/service_animaux.png';
  }
  if (norm == 'showers' || norm.contains('docce')) {
    return 'assets/icons/markers/service_douche.png';
  }
  if (norm == 'wifi' || norm.contains('wi-fi') || norm.contains('wi‑fi')) {
    return 'assets/icons/markers/service_wifi.png';
  }
  if (norm == 'electricity' || norm.contains('elettric')) {
    return 'assets/icons/markers/service_electricite.png';
  }
  if (norm == 'water' ||
      norm.contains('acqua potabile') ||
      (norm.contains('acqua') &&
          !norm.contains('nere') &&
          !norm.contains('grigie') &&
          !norm.contains('black') &&
          !norm.contains('grey'))) {
    return 'assets/icons/markers/service_point_eau.png';
  }
  if (norm == 'black_water' || norm.contains('nere') || norm.contains('black')) {
    return 'assets/icons/markers/service_eau_noire.png';
  }
  if (norm == 'grey_water' ||
      norm.contains('grigie') ||
      norm.contains('grey') ||
      norm.contains('us')) {
    return 'assets/icons/markers/service_eau_usee.png';
  }
  if (norm == 'laundry' || norm.contains('lavanderia')) {
    return 'assets/icons/markers/service_laverie.png';
  }
  if (norm == 'wash' || norm.contains('lavaggio')) {
    return 'assets/icons/markers/service_lavage.png';
  }
  if (norm == 'gpl' || norm.contains('gpl')) {
    return 'assets/icons/markers/service_gpl.png';
  }
  if (norm == 'gas' || norm.contains('gaz') || norm.contains('gas')) {
    return 'assets/icons/markers/service_gaz.png';
  }
  if (norm == 'trash' ||
      norm.contains('cestini') ||
      norm.contains('rifiuti') ||
      norm.contains('pattum')) {
    return 'assets/icons/markers/service_poubelle.png';
  }
  if (norm == 'toilet_public' || norm.contains('bagni') || norm.contains('wc')) {
    return 'assets/icons/markers/service_wc_public.png';
  }

  return null;
}

Widget serviceIconWidgetForLabel(String label,
    {double size = 18, Color? tint}) {
  final asset = serviceIconAssetForLabel(label);
  if (asset == null) {
    return Icon(_iconForAmenity(label), size: size, color: tint ?? Colors.white70);
  }
  return Image.asset(asset, width: size, height: size);
}

class _AddSpotScreenState extends ConsumerState<AddSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  double? _lat;
  double? _lng;

  final List<XFile> _photos = [];

  // tipo area: usiamo gli stessi codici backend dei filtri
  String _selectedType = 'area_sosta';

  SpotLocationSource _locationSource = SpotLocationSource.none;

  // Servizi: allineati a FiltersPanel (stesse label)
  final Map<String, bool> _services = {
    'Elettricità': false,
    'Acqua potabile': false,
    'Scarico acque nere': false,
    'Scarico acque grigie': false,
    'Bagni pubblici': false,
    'Docce': false,
    'Wi‑Fi': false,
    'Animali ammessi': false,
    'Lavanderia': false,
    'GPL': false,
    'Lavaggio camper': false,
    'Cestini rifiuti': false,
  };

  // Mappatura label UI -> chiavi backend
  final Map<String, String> _serviceKeyMap = const {
    'Elettricità': 'electricity',
    'Acqua potabile': 'water',
    'Scarico acque nere': 'black_water',
    'Scarico acque grigie': 'grey_water',
    'Bagni pubblici': 'toilet_public',
    'Docce': 'showers',
    'Wi‑Fi': 'wifi',
    'Animali ammessi': 'animals',
    'Lavanderia': 'laundry',
    'GPL': 'gpl',
    'Lavaggio camper': 'wash',
    'Cestini rifiuti': 'trash',
  };

  bool _isSaving = false;

  mb.MapboxMap? _previewMap;
  mb.PointAnnotationManager? _previewAnnoMgr;

  String _assetForSelectedType() {
    switch (_selectedType) {
      case 'campeggio':
        return 'assets/icons/markers/icon_c.png';
      case 'agricampeggio':
        return 'assets/icons/markers/icon_ar.png';
      case 'area_sosta':
      default:
        return 'assets/icons/markers/icon_p.png';
    }
  }

  Future<Uint8List?> _loadMarkerBytes(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _renderPreviewMarker() async {
    final map = _previewMap;
    if (map == null) return;
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;

    _previewAnnoMgr ??= await map.annotations.createPointAnnotationManager();
    await _previewAnnoMgr!.deleteAll();

    final bytes = await _loadMarkerBytes(_assetForSelectedType()) ??
        await _loadMarkerBytes('assets/icons/markers/icon_p.png');

    await _previewAnnoMgr!.create(
      mb.PointAnnotationOptions(
        geometry: mb.Point(coordinates: mb.Position(lng, lat)),
        image: bytes,
        iconSize: 1.4,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Proviamo a preimpostare la posizione così la preview mappa appare subito.
    // Se i permessi non sono disponibili, l'utente può comunque scegliere manualmente.
    Future<void>.delayed(Duration.zero, () async {
      if (!mounted) return;
      if (_lat != null && _lng != null) return;
      final ok = await _ensureLocationPermission();
      if (!ok) return;
      try {
        final position = await Geolocator.getCurrentPosition();
        if (!mounted) return;
        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
          _locationSource = SpotLocationSource.currentLocation;
        });
      } catch (_) {
        // ignore
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _previewAnnoMgr?.deleteAll();
    _previewAnnoMgr = null;
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage();
      if (files.isEmpty) return;
      setState(() {
        _photos.addAll(files);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore durante la selezione delle foto.')),
      );
    }
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servizi di localizzazione disattivati.')),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso di localizzazione negato.')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Permesso di localizzazione negato permanentemente. Abilitalo dalle impostazioni.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _useCurrentLocation() async {
    final ok = await _ensureLocationPermission();
    if (!ok) return;

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationSource = SpotLocationSource.currentLocation;
      });
      _syncPreviewCamera();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossibile ottenere la posizione attuale: $e')),
      );
    }
  }

  Future<void> _chooseLocationOnMap() async {
    final result = await Navigator.of(context).push<Map<String, double>>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _lat,
          initialLng: _lng,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _lat = result['lat'];
        _lng = result['lng'];
        _locationSource = SpotLocationSource.manual;
      });
      _syncPreviewCamera();
    }
  }

  void _onPreviewMapCreated(mb.MapboxMap map) {
    _previewMap = map;
    _syncPreviewCamera();
    _renderPreviewMarker();
  }

  void _syncPreviewCamera() {
    if (_previewMap == null) return;
    final lat = _lat;
    final lng = _lng;
    if (lat == null || lng == null) return;

    _previewMap!.setCamera(
      mb.CameraOptions(
        center: mb.Point(coordinates: mb.Position(lng, lat)),
        zoom: 13.0,
      ),
    );

    _renderPreviewMarker();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una posizione o usa la tua posizione.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // _services: mappa UI (label italiana -> bool)
      // La convertiamo in mappa per il backend (chiave inglese -> bool)
      final Map<String, bool> backendServices = {};
      _services.forEach((uiLabel, enabled) {
        if (enabled != true) return;
        final backendKey = _serviceKeyMap[uiLabel];
        if (backendKey != null) {
          backendServices[backendKey] = true;
        }
      });

      final dto = SpotCreateDto(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        latitude: _lat!,
        longitude: _lng!,
        type: _selectedType,
        services: backendServices,
      );

      final api = ref.read(spotsApiClientProvider);
      await api.createSpot(dto);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il salvataggio: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openServicesPicker() async {
    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return _ServicesPickerSheet(
              initialServices: _services,
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _services
          ..clear()
          ..addAll(result);
      });
    }
  }

  Widget _tipoAreaChip({
    required String value,
    required String label,
    required String asset,
  }) {
    final selected = _selectedType == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) {
        setState(() {
          _selectedType = value;
        });
        _renderPreviewMarker();
      },
      backgroundColor: const Color(0xFF0d221a),
      selectedColor: const Color(0xFF123426),
      side: BorderSide(
        color: selected ? const Color(0xFF1b7f6b) : const Color(0xFF3b4a3a),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 18, height: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const cardBg = Color(0xFF0d221a);
    const primary = Color(0xFF1b7f6b);

    String locationLabel;
    IconData locationIcon;
    switch (_locationSource) {
      case SpotLocationSource.currentLocation:
        locationLabel = _lat != null && _lng != null
            ? 'Mia posizione attuale: Lat ${_lat!.toStringAsFixed(4)}, Lng ${_lng!.toStringAsFixed(4)}'
            : 'Posizione attuale non disponibile';
        locationIcon = Icons.my_location;
        break;
      case SpotLocationSource.manual:
        locationLabel = _lat != null && _lng != null
            ? 'Posizione selezionata: Lat ${_lat!.toStringAsFixed(4)}, Lng ${_lng!.toStringAsFixed(4)}'
            : 'Posizione non impostata';
        locationIcon = Icons.place;
        break;
      case SpotLocationSource.none:
        locationLabel = 'Posizione non impostata';
        locationIcon = Icons.help_outline;
        break;
    }

    final selectedServices = _services.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    String servicesSummary;
    if (selectedServices.isEmpty) {
      servicesSummary = 'Nessun servizio selezionato';
    } else if (selectedServices.length <= 2) {
      servicesSummary = selectedServices.join(', ');
    } else {
      servicesSummary =
          '${selectedServices.take(2).join(', ')} +${selectedServices.length - 2}';
    }

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: darkBg,
        elevation: 0,
        title: const Text(
          'Aggiungi nuovo spot',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Nome spot
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nome spot',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primary),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Inserisci un nome per lo spot';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      // Sezione posizione (aggiornata a reale)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Posizione',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(locationIcon,
                                        size: 16, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        locationLabel,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _useCurrentLocation,
                                child: const Text('Usa mia posizione'),
                              ),
                              TextButton(
                                onPressed: _chooseLocationOnMap,
                                child: const Text('Scegli sulla mappa'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Preview mappa (ripristinata)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 160,
                          width: double.infinity,
                          child: _lat != null && _lng != null
                              ? mb.MapWidget(
                                  key: const ValueKey('add_spot_preview_map'),
                                  cameraOptions: mb.CameraOptions(
                                    center: mb.Point(
                                      coordinates: mb.Position(_lng!, _lat!),
                                    ),
                                    zoom: 13.0,
                                  ),
                                  styleUri: mb.MapboxStyles.MAPBOX_STREETS,
                                  onMapCreated: _onPreviewMapCreated,
                                )
                              : Container(
                                  color: cardBg,
                                  child: const Center(
                                    child: Text(
                                      "Imposta una posizione per vedere l'anteprima sulla mappa",
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // === Tipo di area (con icone marker PNG) ===
                      const Text(
                        'Tipo di area',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _tipoAreaChip(
                            value: 'area_sosta',
                            label: 'Area di sosta',
                            asset: 'assets/icons/markers/icon_p.png',
                          ),
                          _tipoAreaChip(
                            value: 'campeggio',
                            label: 'Campeggio',
                            asset: 'assets/icons/markers/icon_c.png',
                          ),
                          _tipoAreaChip(
                            value: 'agricampeggio',
                            label: 'Agricampeggio',
                            asset: 'assets/icons/markers/icon_ar.png',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrizione breve',
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Servizi disponibili',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _openServicesPicker,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF3b4a3a)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune,
                                  color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  servicesSummary,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white54, size: 20),
                            ],
                          ),
                        ),
                      ),
                      if (selectedServices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final name in selectedServices.take(4))
                              GestureDetector(
                                onTap: _openServicesPicker,
                                child: Chip(
                                  backgroundColor: const Color(0xFF123426),
                                  labelPadding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 0),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      serviceIconWidgetForLabel(name, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (selectedServices.length > 4)
                              GestureDetector(
                                onTap: _openServicesPicker,
                                child: Chip(
                                  backgroundColor: const Color(0xFF123426),
                                  label: Text(
                                    '+${selectedServices.length - 4}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      const Text(
                        'Foto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _pickPhotos,
                            icon: const Icon(Icons.add_a_photo, size: 18),
                            label: const Text('Aggiungi foto'),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _photos.isEmpty
                                ? 'Nessuna foto selezionata'
                                : '${_photos.length} foto selezionate',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_photos.isNotEmpty)
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final file = File(_photos[index].path);
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  file,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 90,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF123426)),
                          ),
                          child: const Center(
                            child: Text(
                              'Nessuna foto ancora. Tocca "Aggiungi foto" per caricare le immagini dello spot.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(
                color: darkBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm & Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _iconForAmenity(String label) {
  final lower = label.toLowerCase();
  if (lower.contains('elettric')) return Icons.bolt;
  if (lower.contains('acqua potabile')) return Icons.water_drop;
  if (lower.contains('nere')) return Icons.delete_outline;
  if (lower.contains('grigie')) return Icons.water_damage;
  if (lower.contains('bagni') || lower.contains('wc')) return Icons.wc;
  if (lower.contains('docce')) return Icons.shower;
  if (lower.contains('wi‑fi') || lower.contains('wifi')) return Icons.wifi;
  if (lower.contains('animali')) return Icons.pets;
  if (lower.contains('lavanderia')) return Icons.local_laundry_service;
  if (lower.contains('gpl')) return Icons.local_gas_station;
  if (lower.contains('lavaggio')) return Icons.local_car_wash;
  if (lower.contains('cestini')) return Icons.delete;
  return Icons.check_circle_outline;
}

class _ServicesPickerSheet extends StatefulWidget {
  final Map<String, bool> initialServices;
  final ScrollController scrollController;

  const _ServicesPickerSheet({
    required this.initialServices,
    required this.scrollController,
  });

  @override
  State<_ServicesPickerSheet> createState() => _ServicesPickerSheetState();
}

class _ServicesPickerSheetState extends State<_ServicesPickerSheet> {
  late Map<String, bool> _localServices;

  @override
  void initState() {
    super.initState();
    _localServices = Map<String, bool>.from(widget.initialServices);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF071814);

    return Container(
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Seleziona i servizi presenti nello spot',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _AmenitiesSelection(services: _localServices),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Annulla'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop<Map<String, bool>>(_localServices);
                  },
                  child: const Text('Salva'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmenitiesSelection extends StatefulWidget {
  final Map<String, bool> services;

  const _AmenitiesSelection({required this.services});

  @override
  State<_AmenitiesSelection> createState() => _AmenitiesSelectionState();
}

class _AmenitiesSelectionState extends State<_AmenitiesSelection> {
  @override
  Widget build(BuildContext context) {
    const tileBg = Color(0xFF0d221a);
    const borderColor = Color(0xFF3b4a3a);

    final entries = widget.services.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final crossAxisCount = isNarrow ? 1 : 2;
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.5,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final e = entries[index];
            final selected = e.value;
            return GestureDetector(
              onTap: () {
                setState(() {
                  widget.services[e.key] = !selected;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected ? Colors.white12 : tileBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? Colors.white70 : borderColor,
                  ),
                ),
                child: Row(
                  children: [
                    // Use PNG service icons when available
                    serviceIconWidgetForLabel(e.key, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
