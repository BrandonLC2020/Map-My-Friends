import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class ThermalResponse extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;

  const ThermalResponse({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 8.0,
  });

  @override
  State<ThermalResponse> createState() => _ThermalResponseState();
}

class _ThermalResponseState extends State<ThermalResponse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _glowAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown() {
    _controller.animateTo(1.0, duration: const Duration(milliseconds: 50));
  }

  void _handleTapUp() {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (_glowAnimation.value > 0)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: MapPalette.thermalCore.withValues(
                          alpha: 0.5 * _glowAnimation.value,
                        ),
                        blurRadius: 20 * _glowAnimation.value,
                        spreadRadius: 5 * _glowAnimation.value,
                      ),
                      BoxShadow(
                        color: MapPalette.thermalCorona.withValues(
                          alpha: 0.3 * _glowAnimation.value,
                        ),
                        blurRadius: 40 * _glowAnimation.value,
                        spreadRadius: 10 * _glowAnimation.value,
                      ),
                    ],
                  ),
                ),
              ),
            widget.child,
          ],
        );
      },
    );

    if (widget.onTap != null) {
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: content,
      );
    }

    return Listener(
      onPointerDown: (_) => _handleTapDown(),
      onPointerUp: (_) => _handleTapUp(),
      onPointerCancel: (_) => _handleTapCancel(),
      behavior: HitTestBehavior.translucent,
      child: content,
    );
  }
}
