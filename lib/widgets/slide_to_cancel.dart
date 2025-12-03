import 'package:flutter/material.dart';

class SlideToCancel extends StatefulWidget {
  final VoidCallback onCancelled;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final Color sliderColor;

  const SlideToCancel({
    super.key,
    required this.onCancelled,
    this.label = "Slide to Cancel",
    this.backgroundColor = const Color(0xFFFFEBEE), // Light Red
    this.iconColor = Colors.red,
    this.sliderColor = Colors.white,
  });

  @override
  State<SlideToCancel> createState() => _SlideToCancelState();
}

class _SlideToCancelState extends State<SlideToCancel> {
  double _dragValue = 0.0;
  double _maxWidth = 0.0;
  bool _isCancelled = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _maxWidth = constraints.maxWidth;
        return Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              // Label
              Center(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.iconColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              // Slider
              Positioned(
                left: _dragValue,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    if (_isCancelled) return;
                    setState(() {
                      _dragValue = (_dragValue + details.delta.dx).clamp(
                        0.0,
                        _maxWidth - 56,
                      );
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    if (_isCancelled) return;
                    if (_dragValue > _maxWidth * 0.7) {
                      // Trigger Cancel
                      setState(() {
                        _dragValue = _maxWidth - 56;
                        _isCancelled = true;
                      });
                      widget.onCancelled();
                    } else {
                      // Reset
                      setState(() {
                        _dragValue = 0.0;
                      });
                    }
                  },
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: widget.sliderColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.close, color: widget.iconColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
