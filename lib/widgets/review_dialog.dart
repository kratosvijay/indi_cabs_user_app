import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';

class ReviewDialog extends StatefulWidget {
  final String rideRequestId;
  final String driverId;
  final String userId;
  final bool isRental;

  const ReviewDialog({
    super.key,
    required this.rideRequestId,
    required this.driverId,
    required this.userId,
    this.isRental = false,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReview() async {
    if (_rating == 0) {
      displaySnackBar(context, "Please select a rating of at least 1 star.");
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      debugPrint("Submitting review for ride: ${widget.rideRequestId}, driver: ${widget.driverId}");

      // 1. Add review to 'reviews' collection
      final reviewRef = FirebaseFirestore.instance.collection('reviews').doc();
      await reviewRef.set({
        'rideId': widget.rideRequestId,
        'driverId': widget.driverId,
        'userId': widget.userId,
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
        'isRental': widget.isRental,
      });
      debugPrint("Review document created: ${reviewRef.id}");

      // 2. Mark ride request as reviewed
      final rideCollection = widget.isRental ? 'rental_requests' : 'ride_requests';
      await FirebaseFirestore.instance
          .collection(rideCollection)
          .doc(widget.rideRequestId)
          .update({'reviewed': true});
      debugPrint("Ride request marked as reviewed in $rideCollection");

      // 3. Update driver rating and ratingCount (Skip if driverId is missing)
      if (widget.driverId.isNotEmpty) {
        try {
          final driverRef = FirebaseFirestore.instance.collection('drivers').doc(widget.driverId);
          
          await FirebaseFirestore.instance.runTransaction((transaction) async {
            final driverSnapshot = await transaction.get(driverRef);
            if (driverSnapshot.exists) {
              final data = driverSnapshot.data()!;
              final currentRating = (data['rating'] as num?)?.toDouble() ?? 5.0; // default 5.0
              final currentCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

              // Calculate new average
              final newCount = currentCount + 1;
              final totalScore = currentCount == 0 ? 0.0 : (currentRating * currentCount);
              final newRating = (totalScore + _rating) / newCount;

              transaction.update(driverRef, {
                'rating': double.parse(newRating.toStringAsFixed(1)),
                'ratingCount': newCount,
              });
            } else {
              debugPrint("Driver document not found for rating update: ${widget.driverId}");
            }
          });
          debugPrint("Driver rating updated successfully");
        } catch (driverError) {
          // Log but don't fail the entire review if driver update fails
          debugPrint("Non-critical error updating driver rating: $driverError");
        }
      } else {
        debugPrint("Skipping driver rating update because driverId is empty");
      }

      if (mounted) {
        Get.back(); // close dialog
        displaySnackBar(context, "Thank you for your review!", isError: false);
      }
    } catch (e) {
      debugPrint("CRITICAL Error submitting review: $e");
      if (mounted) {
        displaySnackBar(context, "Failed to submit review. Please try again.");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "How was your ride?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Please rate your driver and leave a comment.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              FittedBox(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    return IconButton(
                      iconSize: 40,
                      icon: Icon(
                        index < _rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        setState(() {
                          _rating = index + 1;
                        });
                      },
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _commentController,
                maxLines: 3,
                maxLength: 250,
                decoration: InputDecoration(
                  hintText: "Write your comment here (optional)",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isSubmitting)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(),
                        child: Text(
                          "Skip",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _rating > 0 ? Colors.blueAccent : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _rating > 0 ? _submitReview : null,
                        child: const Text(
                          "Submit",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
