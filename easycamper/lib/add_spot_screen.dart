import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Aggiunto per rootBundle
import 'package:flutter/foundation.dart'; // Aggiunto per Factory
import 'package:flutter/gestures.dart'; // Aggiunto per EagerGestureRecognizer
import 'dart:io';
import 'dart:math'; // Aggiunto per Point
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'mapbox_config.dart';
import 'api/spots_api.dart';

class _MockLocation {
  final double latitude;
  final double longitude;
  const _MockLocation(this.latitude, this.longitude);
}

enum SpotLocationSource { none, currentLocation, manual }

class AddSpotScreen extends ConsumerStatefulWidget {
  const AddSpotScreen({super.key});

  @override
  ConsumerState<AddSpotScreen> createState() => _AddSpotScreenState();
}

class _AddSpotScreenState extends ConsumerState<AddSpotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  MapboxMapController? _mapController;

  double? _lat;
  double? _lng;

  final List<XFile> _photos = [];

  // tipo area: usiamo gli stessi codici backend dei filtri
  String _selectedType = 'area_sosta';

  SpotLocationSource _locationSource = SpotLocationSource.none;
  
  // Default location (Italy center) if no location is selected
  static const double _defaultLat = 41.8719;
  static const double _defaultLng = 12.5674;
  static const double _defaultZoom = 5.0;

  // Servizi: allineati a FiltersPanel (stesse label)
  final Map<String, bool> _services = const {
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
    'Bagni pubblici': 'toilet',
    'Docce': 'showers',
    'Wi‑Fi': 'wifi',
    'Animali ammessi': 'pets',
    'Lavanderia': 'laundry',
    'GPL': 'gpl',
    'Lavaggio camper': 'car_wash',
    'Cestini rifiuti': 'trash_cans',
  };

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    try {
      final files = await picker.pickMultiImage();
      if (files == null || files.isEmpty) return;
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

  void _useMockLocation() {
    // TODO: sostituire con geolocalizzazione reale
    setState(() {
      _lat = 45.4642;
      _lng = 9.1900;
      _locationSource = SpotLocationSource.currentLocation;
    });
    _updateMapPreview();
  }
  
  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
    // Se abbiamo già una posizione, aggiungiamo il marker
    if (_lat != null && _lng != null) {
      _updateMapMarker();
    }
  }

  void _onStyleLoadedCallback() {
    // Rimuoviamo le etichette dei POI nativi anche qui
    try {
      _mapController?.removeLayer("poi-label");
    } catch (e) {
      debugPrint("Impossibile rimuovere poi-label: $e");
    }

    _loadMarkerImages();
    if (_lat != null && _lng != null) {
      _updateMapMarker();
    }
  }

  Future<void> _loadMarkerImages() async {
    if (_mapController == null) return;
    try {
      await _addImageFromAsset('icon_p', 'assets/icons/icon_p.png');
      await _addImageFromAsset('icon_c', 'assets/icons/icon_c.png');
      await _addImageFromAsset('icon_apn', 'assets/icons/icon_apn.png');
    } catch (e) {
      debugPrint('Errore caricamento icone marker: $e');
    }
  }

  Future<void> _addImageFromAsset(String name, String assetPath) async {
    final ByteData bytes = await rootBundle.load(assetPath);
    final Uint8List list = bytes.buffer.asUint8List();
    await _mapController!.addImage(name, list);
  }

  void _onMapClick(Point<double> point, LatLng coordinates) {
    setState(() {
      _lat = coordinates.latitude;
      _lng = coordinates.longitude;
      _locationSource = SpotLocationSource.manual;
    });
    _updateMapMarker();
  }

  void _updateMapPreview() {
    if (_mapController != null && _lat != null && _lng != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(_lat!, _lng!), 14),
      );
      _updateMapMarker();
    }
  }

  void _updateMapMarker() {
    if (_mapController == null || _lat == null || _lng == null) return;
    
    String iconImage = 'icon_p';
    if (_selectedType == 'campeggio') iconImage = 'icon_c';
    if (_selectedType == 'agricampeggio') iconImage = 'icon_apn';

    _mapController!.clearSymbols();
    _mapController!.addSymbol(
      SymbolOptions(
        geometry: LatLng(_lat!, _lng!),
        iconImage: iconImage,
        iconSize: 1.5,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona una posizione sulla mappa.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // _services: mappa UI (label italiana -> bool)
      // La convertiamo in lista di chiavi backend
      final List<String> backendServices = [];
      _services.forEach((uiLabel, enabled) {
        if (enabled != true) return;
        final backendKey = _serviceKeyMap[uiLabel];
        if (backendKey != null) {
          backendServices.add(backendKey);
        }
      });

      final api = ref.read(spotsApiClientProvider);
      final List<String> uploadedPhotoUrls = [];

      // 1. Upload delle foto (se presenti)
      if (_photos.isNotEmpty) {
        for (final xfile in _photos) {
          final file = File(xfile.path);
          try {
            final url = await api.uploadImage(file);
            uploadedPhotoUrls.add(url);
          } catch (e) {
            debugPrint('Errore upload foto ${xfile.path}: $e');
            // Continuiamo con le altre foto o ci fermiamo?
            // Per ora logghiamo e proseguiamo, l'utente avrà meno foto del previsto.
          }
        }
      }

      // 2. Creazione dello spot con gli URL delle foto
      final dto = SpotCreateDto(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        latitude: _lat!,
        longitude: _lng!,
        type: _selectedType,
        services: backendServices,
        photos: uploadedPhotoUrls,
      );

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
    final scrollController = ScrollController();
    final result = await showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return _ServicesPickerSheet(
              initialServices: _services,
              scrollController: controller,
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _services
          ..clear()
          ..addAll(result);
      });
    }
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
      default:
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
                                onPressed: _useMockLocation,
                                child: const Text('Usa mia posizione'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: MapboxMap(
                            accessToken: mapboxAccessToken,
                            styleString: MapboxStyles.MAPBOX_STREETS,
                            compassEnabled: true,
                            compassViewPosition: CompassViewPosition.TopRight,
                            compassViewMargins: const Point(16, 150),
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _lat ?? _defaultLat, 
                                _lng ?? _defaultLng
                              ),
                              zoom: _lat != null ? 14 : _defaultZoom,
                            ),
                            onMapCreated: _onMapCreated,
                            onStyleLoadedCallback: _onStyleLoadedCallback,
                            onMapClick: _onMapClick,
                            // Abilitiamo tutte le gesture per massima interattività
                            scrollGesturesEnabled: true,
                            zoomGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            tiltGesturesEnabled: true,
                            doubleClickZoomEnabled: true,
                            // Abilitiamo la posizione utente e il tracking iniziale
                            myLocationEnabled: true,
                            myLocationTrackingMode: MyLocationTrackingMode.Tracking,
                            myLocationRenderMode: MyLocationRenderMode.COMPASS,
                            // Questo permette alla mappa di catturare subito i gesti, 
                            // impedendo alla pagina di scrollare quando si tocca la mappa
                            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                              Factory<ScaleGestureRecognizer>(
                                () => ScaleGestureRecognizer(),
                              ),
                              Factory<VerticalDragGestureRecognizer>(
                                () => VerticalDragGestureRecognizer(),
                              ),
                            },
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Tocca sulla mappa per posizionare lo spot',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // === Tipo di area (allineato ai filtri) ===
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
                          _buildTipoAreaChip('area_sosta', 'Area di sosta', 'assets/icons/icon_p.png'),
                          _buildTipoAreaChip('campeggio', 'Campeggio', 'assets/icons/icon_c.png'),
                          _buildTipoAreaChip('agricampeggio', 'Agricampeggio', 'assets/icons/icon_apn.png'),
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
                                      _ServiceIcon(
                                        name,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
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

  Widget _buildTipoAreaChip(String value, String label, String assetPath) {
    final isSelected = _selectedType == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            assetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.place, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedType = value; // già nel formato backend usato dai filtri
        });
        _updateMapMarker(); // Aggiorna il marker quando cambia il tipo
      },
      selectedColor: const Color(0xFF1b7f6b),
      backgroundColor: const Color(0xFF0d221a),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.white70,
      ),
    );
  }
}

String? _getAssetForService(String key) {
  final lower = key.toLowerCase();
  if (lower.contains('elettric')) return 'assets/icons/service_electricite.png';
  if (lower.contains('acqua potabile') || lower.contains('potabile')) return 'assets/icons/service_point_eau.png';
  if (lower.contains('nere')) return 'assets/icons/service_eau_noire.png';
  if (lower.contains('grigie')) return 'assets/icons/service_eau_usee.png';
  if (lower.contains('bagni') || lower.contains('wc')) return 'assets/icons/service_wc_public.png';
  if (lower.contains('docce')) return 'assets/icons/service_douche.png';
  if (lower.contains('wi‑fi') || lower.contains('wifi')) return 'assets/icons/service_wifi.png';
  if (lower.contains('animali')) return 'assets/icons/service_animaux.png';
  if (lower.contains('lavanderia')) return 'assets/icons/service_laverie.png';
  if (lower.contains('gpl')) return 'assets/icons/service_gpl.png';
  if (lower.contains('lavaggio')) return 'assets/icons/service_lavage.png';
  if (lower.contains('cestini') || lower.contains('rifiuti')) return 'assets/icons/service_poubelle.png';
  return null;
}

class _ServiceIcon extends StatelessWidget {
  final String serviceName;
  final double size;
  final Color? color;

  const _ServiceIcon(this.serviceName, {this.size = 20, this.color});

  @override
  Widget build(BuildContext context) {
    final asset = _getAssetForService(serviceName);
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.check_circle_outline, size: size, color: color ?? Colors.white70),
      );
    }
    return Icon(Icons.check_circle_outline, size: size, color: color ?? Colors.white70);
  }
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
                    _ServiceIcon(
                      e.key,
                      size: 20,
                      color: Colors.white70,
                    ),
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
