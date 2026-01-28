import 'package:flutter/material.dart';

class EqualizerLoading extends StatefulWidget {
  final bool isDark;

  const EqualizerLoading({super.key, required this.isDark});

  @override
  State<EqualizerLoading> createState() => _EqualizerLoadingState();
}

class _EqualizerLoadingState extends State<EqualizerLoading>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(4, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 300 + (index * 100)),
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 4,
        end: 14,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedBuilder(
            animation: _animations[index],
            builder: (context, child) {
              return Container(
                width: 3,
                height: _animations[index].value,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
