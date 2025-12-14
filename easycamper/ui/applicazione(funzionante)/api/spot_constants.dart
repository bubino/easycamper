import 'package:flutter/material.dart';

class SpotType {
  static const String camping = 'camping';
  static const String areaSosta = 'area_sosta';
  static const String agricampeggio = 'agricampeggio';
  static const String wildCamping = 'wild_camping';

  static const Map<String, String> labels = {
    camping: 'Campeggio',
    areaSosta: 'Area Sosta',
    agricampeggio: 'Agricampeggio',
    wildCamping: 'Wild Camping',
  };

  static const Map<String, IconData> icons = {
    camping: Icons.cabin,
    areaSosta: Icons.rv_hookup,
    agricampeggio: Icons.agriculture,
    wildCamping: Icons.landscape,
  };

  static String getLabel(String type) => labels[type] ?? type;
  static IconData getIcon(String type) => icons[type] ?? Icons.place;
}

class SpotService {
  static const String electricity = 'electricity';
  static const String water = 'water';
  static const String wasteDisposal = 'waste_disposal';
  static const String wifi = 'wifi';
  static const String showers = 'showers';
  static const String toilets = 'toilets';
  static const String pets = 'pets';
  static const String restaurant = 'restaurant';
  static const String shop = 'shop';
  static const String playground = 'playground';
  static const String laundry = 'laundry';

  static const Map<String, String> labels = {
    electricity: 'Elettricità',
    water: 'Acqua',
    wasteDisposal: 'Scarico',
    wifi: 'Wi-Fi',
    showers: 'Docce',
    toilets: 'Bagni',
    pets: 'Animali ammessi',
    restaurant: 'Ristorante',
    shop: 'Market',
    playground: 'Parco giochi',
    laundry: 'Lavanderia',
  };

  static const Map<String, IconData> icons = {
    electricity: Icons.bolt,
    water: Icons.water_drop,
    wasteDisposal: Icons.delete_outline,
    wifi: Icons.wifi,
    showers: Icons.shower,
    toilets: Icons.wc,
    pets: Icons.pets,
    restaurant: Icons.restaurant,
    shop: Icons.shopping_cart,
    playground: Icons.park,
    laundry: Icons.local_laundry_service,
  };

  static String getLabel(String service) => labels[service] ?? service;
  static IconData getIcon(String service) => icons[service] ?? Icons.check_circle_outline;
}
