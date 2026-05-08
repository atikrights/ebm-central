import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget? child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final LinearGradient? gradient;
  final Border? border;

  const GlassContainer({
    super.key,
    this.child,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.blur = 10.0,
    this.padding = const EdgeInsets.all(20.0),
    this.gradient,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 20,
              spreadRadius: -5,
              offset: const Offset(0, 10),
            )
          else ...[
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: AppColors.primary.withOpacity(0.02),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: gradient ??
                  LinearGradient(
                    colors: [
                      isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.98),
                      isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
              border: border ??
                  Border.all(
                    color: isDark ? Colors.white.withOpacity(0.15) : Colors.white,
                    width: isDark ? 1.0 : 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
