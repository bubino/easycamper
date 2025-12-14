import 'package:flutter/material.dart';

class FiltersPanel extends StatefulWidget {
  final Function(Map<String, dynamic>)? onFiltersChanged;
  const FiltersPanel({
    super.key,
    this.onFiltersChanged,
  });

  @override
  State<FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<FiltersPanel> {
  // Tipo di Area: usiamo direttamente i codici backend
  // che poi verranno letti in MapScreen._buildFilters
  // e passati a SpotFilters.types
  final Map<String, bool> _tipiArea = {
    'area_sosta': false,
    'campeggio': false,
    'agricampeggio': false,
  };

  // Servizi: chiave = codice backend (riutilizzabile ovunque),
  // valore = se selezionato; per mostrare in UI usiamo _serviziLabels.
  final Map<String, bool> _servizi = {
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

  double _minRating = 0;
  double _raggio = 20;

  void _notify() {
    widget.onFiltersChanged?.call({
      'tipiArea': {..._tipiArea},
      'servizi': {..._servizi},
      'minRating': _minRating,
      'raggio': _raggio,
    });
  }

  IconData _iconForTipoArea(String key) {
    switch (key) {
      case 'area_sosta':
        return Icons.local_parking;
      case 'campeggio':
        return Icons.park;
      case 'agricampeggio':
        return Icons.park;
      default:
        return Icons.place;
    }
  }

  IconData _iconForServizio(String key) {
    // le chiavi sono quelle backend, ma qui possiamo mappare con contains
    final lower = key.toLowerCase();
    if (lower.contains('elettric')) return Icons.bolt;
    if (lower.contains('acqua')) return Icons.water_drop;
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
    return Icons.check_box_outline_blank;
  }

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF071814);
    const primary = Color(0xFF1b7f6b);

    final maxHeight = MediaQuery.of(context).size.height * 0.6; // max 60% schermo

    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.circular(24), // arrotondato su tutti e 4 gli angoli
        border: const Border(
          top: BorderSide(color: primary, width: 2),
          bottom: BorderSide(color: primary, width: 2), // bordo verde anche sotto
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header (Filtri + Reset)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filtri',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tipiArea.updateAll((key, value) => false);
                        _servizi.updateAll((key, value) => false);
                        _minRating = 0;
                        _raggio = 20;
                      });
                      _notify(); // invia filtri vuoti a MapScreen
                    },
                    child: const Text(
                      'Reset',
                      style:
                          TextStyle(color: Colors.white, fontFamily: 'Poppins'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Tipo di Area',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mostriamo label leggibili ma usiamo la chiave backend internamente
                    ..._tipiArea.keys.map((k) {
                      String readable;
                      switch (k) {
                        case 'area_sosta':
                          readable = 'Area di sosta';
                          break;
                        case 'campeggio':
                          readable = 'Campeggio';
                          break;
                        case 'agricampeggio':
                          readable = 'Agricampeggio';
                          break;
                        default:
                          readable = k;
                      }
                      return _FilterTile(
                        icon: _iconForTipoArea(k),
                        label: readable,
                        value: _tipiArea[k]!,
                        onChanged: (v) {
                          setState(() => _tipiArea[k] = v);
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Servizi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._servizi.keys.map((k) => _FilterTile(
                          icon: _iconForServizio(k),
                          label: k,
                          value: _servizi[k]!,
                          onChanged: (v) {
                            setState(() => _servizi[k] = v);
                          },
                        )),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Valutazione minima',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: primary),
                        Expanded(
                          child: Slider(
                            value: _minRating,
                            min: 0,
                            max: 5,
                            divisions: 5,
                            label: _minRating == 0
                                ? 'Tutte'
                                : _minRating.toStringAsFixed(1),
                            activeColor: primary,
                            onChanged: (v) {
                              setState(() => _minRating = v);
                              // niente _notify() qui
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Text(
                            _minRating == 0
                                ? 'Tutte'
                                : _minRating.toStringAsFixed(1),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Raggio di ricerca',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed, color: primary),
                        Expanded(
                          child: Slider(
                            value: _raggio,
                            min: 1,
                            max: 100,
                            divisions: 20,
                            label: '${_raggio.round()} km',
                            activeColor: primary,
                            onChanged: (v) {
                              setState(() => _raggio = v);
                              // niente _notify() qui
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: Text(
                            '${_raggio.round()} km',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    _notify();
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Applica filtri'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const tileColor = Color(0xFF0d221a);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF123426)),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white),
        title: Text(
          label,
          style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: Colors.white,
        activeTrackColor: Colors.green,
      ),
    );
  }
}
