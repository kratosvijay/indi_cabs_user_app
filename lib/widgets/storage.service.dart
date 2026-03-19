import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:project_taxi_with_ai/widgets/data_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _searchHistoryKey = 'searchHistory';
  static const int _maxHistoryItems = 5;

  // Loads search history from SharedPreferences
  Future<List<SearchHistoryItem>> loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList(_searchHistoryKey) ?? [];

      List<SearchHistoryItem> parsedHistory = [];
      for (var jsonString in historyJson) {
        try {
          final decoded = jsonDecode(jsonString);
          if (decoded is Map<String, dynamic>) {
            parsedHistory.add(SearchHistoryItem.fromJson(decoded));
          }
        } catch (e) {
          debugPrint("Error parsing individual search history item: $e");
          // Specifically avoid throwing so we don't return an empty array due to one bad item
        }
      }
      return parsedHistory;
    } catch (e) {
      debugPrint("Error loading search history: $e");
      return []; // Return empty list only on critical error
    }
  }

  // Adds a new item to search history and saves it
  Future<List<SearchHistoryItem>> addSearchToHistory({
    required String description,
    required String placeId,
    required String mainText,
    required String secondaryText,
    required List<SearchHistoryItem> currentHistory,
  }) async {
    try {
      final String cleanDesc = description.trim();
      if (cleanDesc.isEmpty) return currentHistory;

      // Make a fresh copy to modify
      List<SearchHistoryItem> updatedHistory = List.from(currentHistory);

      // Remove any existing exact or partial matches
      updatedHistory.removeWhere((item) {
        // Match by placeId if we have one
        if (placeId.isNotEmpty && item.placeId == placeId) return true;
        // Or match strictly by description
        if (item.description.trim() == cleanDesc) return true;
        return false;
      });

      // Insert at the top
      updatedHistory.insert(
        0,
        SearchHistoryItem(
          description: cleanDesc,
          placeId: placeId,
          mainText: mainText,
          secondaryText: secondaryText,
        ),
      );

      // Limit history size
      if (updatedHistory.length > _maxHistoryItems) {
        updatedHistory = updatedHistory.sublist(0, _maxHistoryItems);
      }

      // Save updated history safely
      final prefs = await SharedPreferences.getInstance();
      final historyStrings = updatedHistory
          .map((item) => jsonEncode(item.toJson()))
          .toList();
      await prefs.setStringList(_searchHistoryKey, historyStrings);

      return updatedHistory;
    } catch (e) {
      debugPrint("Error adding search to history: $e");
      return currentHistory; // Return original list on error
    }
  }

  // Optional: Method to clear search history
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      debugPrint("Error clearing search history: $e");
    }
  }
}
