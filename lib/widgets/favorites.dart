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
            return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
          }
          if (snapshot.hasError) {
            debugPrint("Error fetching favorites: ${snapshot.error}");
            return const Center(child: Text("Couldn't load favorites", style: TextStyle(color: Colors.grey)));
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
                child: GestureDetector(
                  onLongPress: () => onFavoriteLongPress(favorite),
                  child: ActionChip(
                     avatar: const Icon(Icons.star_border, size: 16, color: Colors.white70),
                     label: Text(favorite.name),
                     labelStyle: const TextStyle(color: Colors.white),
                     backgroundColor: Colors.blueGrey[600],
                     onPressed: () => onFavoriteTap(favorite),
                     tooltip: favorite.address, // Show full address on hover/long press
                     elevation: 1, pressElevation: 3,
                     materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

