import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final List<Color>? gradientColors;
  final double blur;
  final double opacity;
  final BorderRadius borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.gradientColors,
    this.blur = 12.0,
    this.opacity = 0.6,
    this.borderRadius = const BorderRadius.all(Radius.circular(24.0)),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors ??
              (isDark
                  ? [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
                  : [Colors.black.withOpacity(0.03), Colors.black.withOpacity(0.01)]),
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? null : Colors.white.withOpacity(0.4),
              borderRadius: borderRadius,
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
