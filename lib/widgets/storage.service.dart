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
      return historyJson
          .map((jsonString) {
              try {
                return SearchHistoryItem.fromJson(jsonDecode(jsonString));
              } catch (e) {
                 debugPrint("Error parsing search history item: $e");
                 return null; // Skip invalid items
              }
          })
          .whereType<SearchHistoryItem>() // Filter out nulls
          .toList();
    } catch (e) {
      debugPrint("Error loading search history: $e");
      return []; // Return empty list on error
    }
  }

  // Adds a new item to search history and saves it
  Future<List<SearchHistoryItem>> addSearchToHistory(
      String description, String placeId, List<SearchHistoryItem> currentHistory) async {
    try {
      description = description.trim();
      if (description.isEmpty) return currentHistory; // Don't add empty descriptions

      // Avoid adding duplicate if it's already the most recent
      if (currentHistory.isNotEmpty) {
        final first = currentHistory.first;
        if (first.description == description && (placeId.isEmpty || first.placeId == placeId)) {
           return currentHistory;
        }
      }

      final newItem = SearchHistoryItem(description: description, placeId: placeId);
      List<SearchHistoryItem> updatedHistory = List.from(currentHistory);

      // Remove any previous occurrences of the same item
      updatedHistory.removeWhere((item) =>
          (placeId.isNotEmpty && item.placeId == placeId) || // Match by placeId if available
          (placeId.isEmpty && item.placeId.isEmpty && item.description == description)); // Match by description if placeId is empty

      // Add new item to the beginning
      updatedHistory.insert(0, newItem);

      // Limit history size
      if (updatedHistory.length > _maxHistoryItems) {
        updatedHistory = updatedHistory.sublist(0, _maxHistoryItems);
      }

      // Save updated history
      final prefs = await SharedPreferences.getInstance();
      final historyJson = updatedHistory.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_searchHistoryKey, historyJson);

      return updatedHistory; // Return the updated list
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

