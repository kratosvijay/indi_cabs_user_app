import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- NEW PREFERENCE KEYS ---
// We now track each part of the tour separately.
const String kHasSeenSearchTour = 'hasSeenHomeTour_Part1_Search';
const String kHasSeenServicesTour = 'hasSeenHomeTour_Part2_Services';
const String kHasSeenWalletTour = 'hasSeenHomeTour_Part3_Wallet';
const String kHasSeenScheduleTour = 'hasSeenHomeTour_Part4_Schedule';
// ----------------------------

class ContextualFeatureTour {
  /// A static method to check for a preference key and show a tour step.
  static Future<void> showTourStep({
    required BuildContext context,
    required GlobalKey key,
    required String prefKey,
    required String title,
    required String description,
  }) async {
    // Check if the user has already seen this specific tour part
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool(prefKey) ?? false;

    if (!hasSeen && context.mounted) {
      // Wait for the widget to be findable
      await Future.delayed(const Duration(milliseconds: 100));
      
      final Rect? targetBounds = _getWidgetBounds(key);
      if (targetBounds == null || !context.mounted) return;

      // Show the actual tour dialog
      await showDialog(
        context: context,
        barrierColor: Colors.black.withAlpha(70),
        barrierDismissible: false,
        builder: (dialogContext) {
          return _TourStepDialog(
            targetBounds: targetBounds,
            title: title,
            description: description,
          );
        },
      );

      // Once the dialog is closed, mark this tour part as "seen"
      await prefs.setBool(prefKey, true);
    }
  }

  /// Finds the position of a widget on the screen from its GlobalKey
  static Rect? _getWidgetBounds(GlobalKey key) {
    final RenderBox? renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final position = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(position.dx, position.dy, renderBox.size.width, renderBox.size.height);
    }
    return null;
  }
}

/// The actual dialog widget that shows the highlight and text
class _TourStepDialog extends StatelessWidget {
  final Rect targetBounds;
  final String title;
  final String description;
  
  const _TourStepDialog({
    required this.targetBounds,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    // Decide where to put the text box (above or below the highlight)
    final bool showTextAbove = targetBounds.top > MediaQuery.of(context).size.height * 0.6;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // This is the overlay with a hole in it
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(70),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black, // This color doesn't matter
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Positioned(
                  left: targetBounds.left - 8,
                  top: targetBounds.top - 8,
                  child: Container(
                    width: targetBounds.width + 16,
                    height: targetBounds.height + 16,
                    decoration: BoxDecoration(
                      color: Colors.white, // This color is "cut out"
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // This is the text box
          Positioned(
            top: showTextAbove ? null : targetBounds.bottom + 24, // Show below
            bottom: showTextAbove ? (MediaQuery.of(context).size.height - targetBounds.top + 24) : null, // Show above
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Got it!"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}