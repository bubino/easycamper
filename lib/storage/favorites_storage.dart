import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesStorage {
  static const _prefsKey = 'favorite_spot_ids';

  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
  }

  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, ids.toList());
  }
}

final favoritesStorageProvider = Provider<FavoritesStorage>((ref) {
  return FavoritesStorage();
});

class FavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // async init
    _load();
    return <String>{};
  }

  Future<void> _load() async {
    final ids = await ref.read(favoritesStorageProvider).load();
    state = ids;
  }

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
    await ref.read(favoritesStorageProvider).save(state);
  }

  Future<void> remove(String id) async {
    if (!state.contains(id)) return;
    state = {...state}..remove(id);
    await ref.read(favoritesStorageProvider).save(state);
  }

  Future<void> clear() async {
    state = <String>{};
    await ref.read(favoritesStorageProvider).save(state);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, Set<String>>(
  FavoritesNotifier.new,
);
