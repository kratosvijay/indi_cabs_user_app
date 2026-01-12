import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalProgressWidget extends StatefulWidget {
  final dynamic startedAt; // Can be Timestamp or DateTime
  final int durationHours;
  final double maxDistanceKm;
  final double currentDistanceKm;

  const RentalProgressWidget({
    super.key,
    required this.startedAt,
    required this.durationHours,
    required this.maxDistanceKm,
    required this.currentDistanceKm,
  });

  @override
  State<RentalProgressWidget> createState() => _RentalProgressWidgetState();
}

class _RentalProgressWidgetState extends State<RentalProgressWidget> {
  // Time State
  double _timeProgress = 0.0;
  String _timeRemaining = "";
  bool _isTimeOvertime = false;
  Timer? _timer;

  // Distance State (Calculated immediately in build or here)
  double _distProgress = 0.0;
  String _distRemaining = "";
  bool _isDistOvertime = false;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _updateProgress();
    });
  }

  @override
  void didUpdateWidget(covariant RentalProgressWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentDistanceKm != oldWidget.currentDistanceKm ||
        widget.maxDistanceKm != oldWidget.maxDistanceKm) {
      _updateProgress();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateProgress() {
    // 1. Time Calculation
    if (widget.startedAt != null) {
      DateTime startTime;
      if (widget.startedAt is Timestamp) {
        startTime = (widget.startedAt as Timestamp).toDate();
      } else if (widget.startedAt is DateTime) {
        startTime = widget.startedAt as DateTime;
      } else {
        startTime = DateTime.now(); // Fallback
      }

      final now = DateTime.now();
      final elapsed = now.difference(startTime);
      final totalDuration = Duration(hours: widget.durationHours);

      double tProgress = elapsed.inSeconds / totalDuration.inSeconds;
      _isTimeOvertime = tProgress >= 1.0;
      _timeProgress = tProgress.clamp(0.0, 1.0);

      final remaining = totalDuration - elapsed;
      if (remaining.isNegative) {
        final extra = elapsed - totalDuration;
        final h = extra.inHours;
        final m = extra.inMinutes.remainder(60);
        _timeRemaining = "+ ${h}h ${m}m";
      } else {
        final h = remaining.inHours;
        final m = remaining.inMinutes.remainder(60);
        _timeRemaining = "${h}h ${m}m left";
      }
    }

    // 2. Distance Calculation
    if (widget.maxDistanceKm > 0) {
      double dProgress = widget.currentDistanceKm / widget.maxDistanceKm;
      _isDistOvertime = dProgress >= 1.0;
      _distProgress = dProgress.clamp(0.0, 1.0);

      if (_isDistOvertime) {
        double extra = widget.currentDistanceKm - widget.maxDistanceKm;
        _distRemaining = "+ ${extra.toStringAsFixed(1)} km";
      } else {
        double left = widget.maxDistanceKm - widget.currentDistanceKm;
        _distRemaining = "${left.toStringAsFixed(1)} km left";
      }
    } else {
      _distProgress = 0.0;
      _distRemaining = "0 km";
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildProgressRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String statusText,
    required double progress,
    required bool isOvertime,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color activeColor = isOvertime ? Colors.red : Colors.green;
    final Color textColor = isOvertime
        ? Colors.red
        : (theme.textTheme.bodyLarge?.color ?? Colors.black87);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Text Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Vertical Slider
        SizedBox(
          height: 100,
          width: 40,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double height = constraints.maxHeight;
              final double iconSize = 20.0;
              final double visualProgress = progress;
              final double carTop = (height - iconSize - 4) * visualProgress;

              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Track
                  Container(
                    width: 12,
                    height: height,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Fill
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 12,
                      height: height * progress,
                      decoration: BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  // Icon
                  Positioned(
                    top: carTop,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.cardColor,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Icon(icon, size: iconSize, color: activeColor),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Time Row
          _buildProgressRow(
            context,
            title: "Package Time",
            subtitle: "${widget.durationHours} Hours",
            statusText: _timeRemaining,
            progress: _timeProgress,
            isOvertime: _isTimeOvertime,
            icon: Icons.directions_car,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(
              height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),

          // Distance Row
          _buildProgressRow(
            context,
            title: "Package Distance",
            subtitle: "${widget.maxDistanceKm.toStringAsFixed(0)} Km",
            statusText: _distRemaining,
            progress: _distProgress,
            isOvertime: _isDistOvertime,
            icon: Icons.map, // Or local_taxi
          ),
        ],
      ),
    );
  }
}
