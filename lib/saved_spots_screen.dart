import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/spots_api.dart';
import 'spot_detail_screen.dart';
import 'storage/favorites_storage.dart' show favoritesProvider;

class SavedSpotsScreen extends ConsumerWidget {
  const SavedSpotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesProvider).toList();
    final favorites = ref.read(favoritesProvider.notifier);
    final spotsApi = ref.watch(spotsApiClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferiti'),
      ),
      body: ids.isEmpty
          ? const Center(
              child: Text('Nessuno spot nei preferiti'),
            )
          : ListView.builder(
              itemCount: ids.length,
              itemBuilder: (context, index) {
                final id = ids[index];
                final cached = spotsApi.getCachedSpot(id);

                return Dismissible(
                  key: ValueKey(id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => favorites.remove(id),
                  child: ListTile(
                    title: Text(cached?.name ?? 'Spot $id'),
                    subtitle: Text(
                      cached?.description.isNotEmpty == true
                          ? cached!.description
                          : 'Dettagli non disponibili',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => favorites.remove(id),
                    ),
                    onTap: () async {
                      try {
                        final spot = cached ?? await spotsApi.fetchSpotById(id);
                        if (!context.mounted) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SpotDetailScreen(spot: spot),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Impossibile caricare i dettagli dello spot.'),
                          ),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}