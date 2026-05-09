import 'dart:ui';
import 'dart:io' if (dart.library.html) 'package:frontend/core/utils/io_stub.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../widgets/glass_card.dart';
import '../../features/chat/presentation/chat_detail_screen.dart'; // For CallState
import '../../features/chat/presentation/call_screen.dart';

class WindowTitleBar extends StatelessWidget {
  final bool isDark;

  const WindowTitleBar({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          windowManager.startDragging();
        }
      },
      onDoubleTap: () async {
        if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
          if (await windowManager.isMaximized()) {
            windowManager.unmaximize();
          } else {
            windowManager.maximize();
          }
        }
      },
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F1117), const Color(0xFF161A23)]
                : [const Color(0xFFF5F7FA), const Color(0xFFEEF2F7)],
          ),
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withOpacity(0.07)
                  : Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // App branding
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: Center(child: LiveSignalDot()),
                  ),
                  const SizedBox(width: 9),
                  AnimatedBrandingText(isDark: isDark),

                  // --- GLOBAL CALL STATUS DASHBOARD ---
                  if (CallState.isCallActive)
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(name: CallState.activeUserName!, avatar: CallState.avatar!))),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withOpacity(0.3), width: 0.5),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.call, size: 10, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                "${CallState.activeUserName} • ${_formatCallDuration()}",
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Mac window control dots
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  MacDotButton(color: const Color(0xFFFF5F56), tooltip: 'Close', onTap: () {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      windowManager.close();
                    }
                  }),
                  const SizedBox(width: 9),
                  MacDotButton(color: const Color(0xFFFFBD2E), tooltip: 'Minimize', onTap: () {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      windowManager.minimize();
                    }
                  }),
                  const SizedBox(width: 9),
                  MacDotButton(color: const Color(0xFF28CA41), tooltip: 'Maximize', onTap: () async {
                    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
                      if (await windowManager.isMaximized()) {
                        windowManager.unmaximize();
                      } else {
                        windowManager.maximize();
                      }
                    }
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCallDuration() {
    if (CallState.startTime == null) return "Connecting...";
    final duration = DateTime.now().difference(CallState.startTime!);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}

class MacDotButton extends StatefulWidget {
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const MacDotButton({super.key, required this.color, required this.tooltip, required this.onTap});

  @override
  State<MacDotButton> createState() => _MacDotButtonState();
}

class _MacDotButtonState extends State<MacDotButton> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  bool _pressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _currentScale => _pressed ? 0.82 : _scaleAnim.value;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          setState(() => _hovered = true);
          _ctrl.forward();
        },
        onExit: (_) {
          setState(() { _hovered = false; _pressed = false; });
          _ctrl.reverse();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            setState(() => _pressed = true);
            widget.onTap();
          },
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedBuilder(
            animation: _scaleAnim,
            builder: (context, child) => Transform.scale(
              scale: _currentScale,
              child: child,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 80),
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.4),
                  radius: 0.85,
                  colors: [
                    Color.lerp(Colors.white, widget.color, _pressed ? 0.75 : 0.50)!,
                    widget.color,
                    Color.lerp(widget.color, Colors.black, _pressed ? 0.40 : 0.22)!,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_pressed ? 0.9 : (_hovered ? 0.72 : 0.42)),
                    blurRadius: _pressed ? 18 : (_hovered ? 12 : 5),
                    spreadRadius: _pressed ? 2 : (_hovered ? 1 : 0),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LiveSignalDot extends StatefulWidget {
  const LiveSignalDot({super.key});

  @override
  State<LiveSignalDot> createState() => _LiveSignalDotState();
}

class _LiveSignalDotState extends State<LiveSignalDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const List<Color> _palette = [
    Color(0xFF00E676),
    Color(0xFF00BCD4),
    Color(0xFF7C4DFF),
    Color(0xFFFFAB00),
    Color(0xFFFF5722),
    Color(0xFF00E676),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 333))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _colorAt(double t) {
    final segments = _palette.length - 1;
    final pos = t * segments;
    final idx = pos.floor().clamp(0, segments - 1);
    return Color.lerp(_palette[idx], _palette[idx + 1], pos - idx)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final color = _colorAt(_ctrl.value);
        final glowPulse = 0.7 + 0.3 * (0.5 - (_ctrl.value - 0.5).abs()) * 2;
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.90 * glowPulse), blurRadius: 6, spreadRadius: 1),
              BoxShadow(color: color.withOpacity(0.45 * glowPulse), blurRadius: 14, spreadRadius: 3),
            ],
          ),
        );
      },
    );
  }
}

class AnimatedBrandingText extends StatefulWidget {
  final bool isDark;
  const AnimatedBrandingText({super.key, required this.isDark});

  @override
  State<AnimatedBrandingText> createState() => _AnimatedBrandingTextState();
}

class _AnimatedBrandingTextState extends State<AnimatedBrandingText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  static const List<Color> _rainbow = [
    Color(0xFF00E676), Color(0xFF00BCD4), Color(0xFF7C4DFF), Color(0xFFFF4081),
    Color(0xFFFFAB00), Color(0xFFFF5722), Color(0xFF2979FF),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final double t = _ctrl.value;
        Color? currentColor;
        if (t < 0.2) {
          final double animT = t / 0.2;
          final segments = _rainbow.length - 1;
          final pos = animT * segments;
          final idx = pos.floor().clamp(0, segments - 1);
          currentColor = Color.lerp(_rainbow[idx], _rainbow[idx + 1], pos - idx)!;
        }
        final baseColor = widget.isDark ? Colors.white : Colors.black;
        final baseOpacity = widget.isDark ? 0.75 : 0.70;
        final contrastOpacity = widget.isDark ? 0.40 : 0.45;

        return RichText(
          text: TextSpan(
            children: [
              TextSpan(text: 'ebm ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: currentColor != null ? currentColor.withOpacity(baseOpacity + 0.15) : baseColor.withOpacity(baseOpacity), letterSpacing: 0.3)),
              TextSpan(text: 'central', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: currentColor != null ? currentColor.withOpacity(contrastOpacity + 0.15) : baseColor.withOpacity(contrastOpacity), letterSpacing: 0.3)),
            ],
          ),
        );
      },
    );
  }
}
