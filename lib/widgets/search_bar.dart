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
  final List<FavoritePlace> favoritePlaces;
  final String pickupAddress; // **NEW**
  final VoidCallback onPickupTap; // **NEW**
  final SearchCallback onSearchChanged;
  final PredictionTapCallback onPredictionTap;
  final HistoryTapCallback onHistoryTap;
  final FocusChangeCallback onFocusChange;
  final ClearSearchCallback onClearSearch;
  final FavoriteToggleCallback onFavoriteToggle;
  final VoidCallback onSelectOnMap;
  final VoidCallback? onMenuTap; // **NEW**

  const SearchBarWidget({
    super.key,
    required this.destinationController,
    required this.destinationFocusNode,
    required this.isSearchEnabled,
    required this.isDestinationSelected,
    required this.predictions,
    required this.searchHistory,
    required this.pickupAddress, // **NEW**
    required this.onPickupTap, // **NEW**
    this.favoritePlaces = const [],
    required this.onSearchChanged,
    required this.onPredictionTap,
    required this.onHistoryTap,
    required this.onFocusChange,
    required this.onClearSearch,
    required this.onFavoriteToggle,
    required this.onSelectOnMap,
    this.onMenuTap, // **NEW**
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

    return Card(
      elevation: 6.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
      ),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated Pickup Field (Upper Box)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: destinationFocusNode.hasFocus
                    ? InkWell(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          onPickupTap();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16.0,
                            horizontal: 16.0,
                          ),
                          child: Row(
                            children: [
                               Icon(
                                Icons.my_location,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  pickupAddress.isNotEmpty
                                      ? pickupAddress
                                      : 'Current Location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Divider between boxes
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: destinationFocusNode.hasFocus
                    ? Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        indent: 16.0,
                        endIndent: 16.0,
                      )
                    : const SizedBox.shrink(),
              ),

              // Text Field Row (Lower Box)
              Row(
                children: [
                  // Leading Icon: Menu (unfocused) or Back (focused)
                  GestureDetector(
                    onTap: () {
                      if (destinationFocusNode.hasFocus) {
                        destinationFocusNode.unfocus();
                        onFocusChange(false);
                      } else {
                        onMenuTap?.call();
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Icon(
                        destinationFocusNode.hasFocus ? Icons.arrow_back : Icons.menu,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                   Expanded(
                    child: TextField(
                      controller: destinationController,
                      focusNode: destinationFocusNode,
                      enabled: isSearchEnabled,
                      decoration: InputDecoration(
                        hintText: isSearchEnabled
                            ? 'Enter drop-off location'
                            : 'Select service type below',
                        prefixIcon: Icon(
                          destinationFocusNode.hasFocus
                              ? Icons.location_on
                              : Icons.search,
                                color: destinationFocusNode.hasFocus
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.white
                                        : Colors.black87)
                                    : Colors.grey,
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
              // Select on Map Button (Visible when focused and empty search)
              if (destinationFocusNode.hasFocus &&
                  destinationController.text.isEmpty &&
                  isSearchEnabled)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 16.0,
                      bottom: 12.0,
                      top: 4.0,
                    ),
                    child: InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        onSelectOnMap();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.map,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Select on Map",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[200]
                                    : Colors.blueAccent[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              // Predictions List (Animated)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: predictions.isNotEmpty
                    ? _buildPredictionsList(context)
                    : const SizedBox.shrink(),
              ),
              // Search History List (Animated & Conditional)
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: showHistory
                    ? _buildSearchHistoryList(context)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
    );
  }

  // Helper for Predictions List
  Widget _buildPredictionsList(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate a safe max height to tuck under keyboard
    // 250 is an estimate of top padding + search bar height
    double maxHeight = screenHeight - keyboardHeight - 250;
    if (maxHeight < 100) maxHeight = 100; // Minimum usable height

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1, thickness: 1),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                  prediction.mainText,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: prediction.secondaryText.isNotEmpty
                    ? Text(
                        prediction.secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12,
                        ),
                      )
                    : null,
                onTap: () => onPredictionTap(prediction.placeId),
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper for Search History List
  Widget _buildSearchHistoryList(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    // Calculate a safe max height to tuck under keyboard
    double maxHeight = screenHeight - keyboardHeight - 280; // Extra room for "Recent Searches" label
    if (maxHeight < 100) maxHeight = 100;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
          Flexible(
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
                      fav.name == historyItem.description ||
                      fav.address == historyItem.mainText ||
                      fav.name == historyItem.mainText,
                );

                return ListTile(
                  leading: const Icon(Icons.history, color: Colors.grey),
                  title: Text(
                    historyItem.mainText.isNotEmpty ? historyItem.mainText : historyItem.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: historyItem.secondaryText.isNotEmpty
                      ? Text(
                          historyItem.secondaryText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 11,
                          ),
                        )
                      : null,
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                    ),
                    onPressed: () => onFavoriteToggle(historyItem, isFavorite),
                  ),
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
