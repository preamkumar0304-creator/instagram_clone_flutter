import 'package:flutter/material.dart';

class LikeAnimation extends StatefulWidget {
  final Widget child;
  final bool isAnimating;
  final Duration duration;
  final VoidCallback? onEnd;
  final bool smallLike;
  const LikeAnimation({
    super.key,
    required this.child,
    required this.isAnimating,
    this.duration = const Duration(milliseconds: 150),
    this.onEnd,
    this.smallLike = false,
  });

  @override
  State<LikeAnimation> createState() => _LikeAnimationState();
}

class _LikeAnimationState extends State<LikeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scale;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: widget.duration);
    final begin = widget.smallLike ? 1.0 : 0.75;
    final end = widget.smallLike ? 1.18 : 1.28;
    scale = Tween<double>(
      begin: begin,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));
  }

  @override
  void didUpdateWidget(covariant LikeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      startAnimation();
    }
  }

  Future<void> startAnimation() async {
    if (!mounted) return;
    await controller.forward(from: 0);
    await controller.reverse();
    if (!mounted) return;
    if (widget.onEnd != null) {
      widget.onEnd!();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: scale, child: widget.child);
  }
}
