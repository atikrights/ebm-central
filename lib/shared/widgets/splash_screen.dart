import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late List<AnimationController> _dotControllers;
  late List<Animation<double>> _dotAnimations;
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  final int dotCount = 7;

  @override
  void initState() {
    super.initState();
    
    // Dot wave animations
    _dotControllers = List.generate(dotCount, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    });

    _dotAnimations = _dotControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOutCubic,
        ),
      );
    }).toList();

    // Main entrance animations
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.6, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic)),
    );

    _mainController.forward();
    _startDotAnimations();
  }

  void _startDotAnimations() async {
    for (int i = 0; i < dotCount; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (mounted) {
        _dotControllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _dotControllers) {
      controller.dispose();
    }
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF8FAFC),
      body: Center(
        child: AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium 7-Dot Wave
                    Container(
                      height: 40,
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(dotCount, (index) {
                          return AnimatedBuilder(
                            animation: _dotAnimations[index],
                            builder: (context, child) {
                              final waveValue = _dotAnimations[index].value;
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                width: 5,
                                height: 5 + (20 * waveValue),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      primary.withOpacity(0.2 + (0.8 * waveValue)),
                                      primary.withOpacity(0.05 + (0.4 * waveValue)),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primary.withOpacity(0.4 * waveValue),
                                      blurRadius: 12 * waveValue,
                                      spreadRadius: 1 * waveValue,
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 48),
                    // High-End Brand Name
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'ebm ',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'central',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w200,
                              color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtle dynamic loading line
                    Container(
                      width: 140,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            primary.withOpacity(0.3),
                            primary.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
