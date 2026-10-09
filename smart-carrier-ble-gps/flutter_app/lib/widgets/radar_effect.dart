import 'package:flutter/material.dart';

class RadarEffect extends StatefulWidget {
  const RadarEffect({super.key, this.size = 80});
  final double size;

  @override
  State<RadarEffect> createState() => _RadarEffectState();
}

class _RadarEffectState extends State<RadarEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this, duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size, height: widget.size,
    child: AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Center(
        child: Container(
          width: widget.size * _animation.value,
          height: widget.size * _animation.value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.withValues(
              alpha: 1 - _animation.value)),
          ),
        ),
      ),
    ),
  );
}
