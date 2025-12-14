import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _prefsKey = 'favorite_spot_ids';

  final Set<String> _favoriteSpotIds = <String>{};
  bool _initialized = false;

  Set<String> get favoriteSpotIds => _favoriteSpotIds;
  bool get isInitialized => _initialized;

  FavoritesProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
      _favoriteSpotIds
        ..clear()
        ..addAll(stored);
      _initialized = true;
      notifyListeners();
    } catch (_) {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _favoriteSpotIds.toList());
    } catch (_) {
      // ignore persistence errors for now
    }
  }

  bool isFavorite(String spotId) => _favoriteSpotIds.contains(spotId);

  Future<void> toggleFavorite(String spotId) async {
    if (_favoriteSpotIds.contains(spotId)) {
      _favoriteSpotIds.remove(spotId);
    } else {
      _favoriteSpotIds.add(spotId);
    }
    notifyListeners();
    await _saveToPrefs();
  }

  Future<void> removeFavorite(String spotId) async {
    if (_favoriteSpotIds.remove(spotId)) {
      notifyListeners();
      await _saveToPrefs();
    }
  }

  Future<void> clear() async {
    if (_favoriteSpotIds.isNotEmpty) {
      _favoriteSpotIds.clear();
      notifyListeners();
      await _saveToPrefs();
    }
  }
}