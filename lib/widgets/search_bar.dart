import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';

// Define callback types
typedef SearchCallback = void Function(String query);
typedef PredictionTapCallback = void Function(String placeId);
typedef HistoryTapCallback = void Function(SearchHistoryItem item);
typedef FocusChangeCallback = void Function(bool hasFocus);
typedef ClearSearchCallback = void Function(); // Callback for clearing search
typedef FavoriteToggleCallback =
    void Function(SearchHistoryItem item, bool isFavorite);

class SearchBarWidget extends StatelessWidget {
  final TextEditingController destinationController;
  final FocusNode destinationFocusNode;
  final bool isSearchEnabled;
  final bool isDestinationSelected;
  final List<PlaceAutocompletePrediction> predictions;
  final List<SearchHistoryItem> searchHistory;
  final List<FavoritePlace> favoritePlaces; // **NEW**
  final SearchCallback onSearchChanged;
  final PredictionTapCallback onPredictionTap;
  final HistoryTapCallback onHistoryTap;
  final FocusChangeCallback onFocusChange;
  final ClearSearchCallback onClearSearch;
  final FavoriteToggleCallback onFavoriteToggle; // **NEW**

  const SearchBarWidget({
    super.key,
    required this.destinationController,
    required this.destinationFocusNode,
    required this.isSearchEnabled,
    required this.isDestinationSelected,
    required this.predictions,
    required this.searchHistory,
    this.favoritePlaces = const [], // Default to empty if not provided
    required this.onSearchChanged,
    required this.onPredictionTap,
    required this.onHistoryTap,
    required this.onFocusChange,
    required this.onClearSearch,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    // This method has 'context'
    bool showHistory =
        destinationFocusNode.hasFocus &&
        destinationController.text.isEmpty &&
        predictions.isEmpty &&
        searchHistory.isNotEmpty &&
        isSearchEnabled;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          0,
        ), // Adjust top padding
        child: Card(
          elevation: 6.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text Field Row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: destinationController,
                      focusNode: destinationFocusNode,
                      enabled: isSearchEnabled,
                      decoration: InputDecoration(
                        hintText: isSearchEnabled
                            ? 'Enter drop-off location'
                            : 'Select service type below',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 15.0,
                          horizontal: 16.0,
                        ),
                        // Clear button inside text field
                        suffixIcon:
                            destinationController.text.isNotEmpty &&
                                isSearchEnabled
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.grey,
                                ),
                                onPressed: onClearSearch,
                              )
                            : null,
                      ),
                      onChanged: onSearchChanged,
                      onTap: () {
                        if (!isSearchEnabled) {
                          FocusScope.of(context).unfocus();
                        }
                        onFocusChange(true);
                      },
                      onEditingComplete: () => onFocusChange(false),
                      onSubmitted: (_) => onFocusChange(false),
                    ),
                  ),
                ],
              ),
              // Predictions List (Animated)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: predictions.isNotEmpty
                    // **FIXED:** Pass context
                    ? _buildPredictionsList(context)
                    : const SizedBox.shrink(),
              ),
              // Search History List (Animated & Conditional)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: showHistory
                    // **FIXED:** Pass context
                    ? _buildSearchHistoryList(context)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for Predictions List
  // **FIXED:** Added BuildContext context
  Widget _buildPredictionsList(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 1),
        ConstrainedBox(
          // **FIXED:** Use context
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.3,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: predictions.length,
            itemBuilder: (context, index) {
              final prediction = predictions[index];
              return ListTile(
                leading: const Icon(
                  Icons.location_on_outlined,
                  color: Colors.grey,
                ),
                title: Text(
                  prediction.description,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                dense: true,
                onTap: () => onPredictionTap(prediction.placeId),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper for Search History List
  // **FIXED:** Added BuildContext context
  Widget _buildSearchHistoryList(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ConstrainedBox(
      // **FIXED:** Use context
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
            child: Text(
              "Recent Searches",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: searchHistory.length,
              itemBuilder: (context, index) {
                final historyItem = searchHistory[index];

                // Check if this item exists in favorites by name or address
                final isFavorite = favoritePlaces.any(
                  (fav) =>
                      fav.address == historyItem.description ||
                      fav.name == historyItem.description,
                );

                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    historyItem.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => onFavoriteToggle(historyItem, isFavorite),
                  ),
                  dense: true,
                  onTap: () => onHistoryTap(historyItem),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
