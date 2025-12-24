import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:project_taxi_with_ai/widgets/firestore_services.dart';

// Define callback types
typedef FavoriteTapCallback = void Function(FavoritePlace favorite);
typedef FavoriteLongPressCallback = void Function(FavoritePlace favorite);

class FavoritesWidget extends StatelessWidget {
  final String userId; // Added userId
  final FirestoreService firestoreService;
  final FavoriteTapCallback onFavoriteTap;
  final FavoriteLongPressCallback onFavoriteLongPress;

  const FavoritesWidget({
    super.key,
    required this.userId, // Added userId
    required this.firestoreService,
    required this.onFavoriteTap,
    required this.onFavoriteLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45, // Slightly increased height for chips
      child: StreamBuilder<List<FavoritePlace>>(
        // **FIXED:** Pass the userId to the stream
        stream: firestoreService.getFavoritesStream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          if (snapshot.hasError) {
            debugPrint("Error fetching favorites: ${snapshot.error}");
            return const Center(
              child: Text(
                "Couldn't load favorites",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink(); // Or Text("No favorites yet!")
          }

          final favorites = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            scrollDirection: Axis.horizontal,
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite = favorites[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Material(
                  color: Colors.blueGrey[600],
                  borderRadius: BorderRadius.circular(20),
                  elevation: 1,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => onFavoriteTap(favorite),
                    onLongPress: () => onFavoriteLongPress(favorite),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_border,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            favorite.name,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
