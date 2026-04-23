import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:async';
import '../../../shared/widgets/glass_card.dart';
import 'call_screen.dart';

class CallController extends ChangeNotifier {
  static final CallController instance = CallController();
  
  String? activeUserName;
  DateTime? startTime;
  bool isCallActive = false;
  bool isVideo = false;
  String? avatar;

  void startCall({required String name, required String avatar, bool isVideo = false}) {
    this.activeUserName = name;
    this.avatar = avatar;
    this.isVideo = isVideo;
    this.isCallActive = true;
    this.startTime = DateTime.now();
    notifyListeners();
  }

  void endCall() {
    isCallActive = false;
    startTime = null;
    notifyListeners();
  }

  void pulse() => notifyListeners(); // For timer updates
}

// Keep CallState as legacy bridge for easier refactoring
class CallState {
  static String? get activeUserName => CallController.instance.activeUserName;
  static DateTime? get startTime => CallController.instance.startTime;
  static bool get isCallActive => CallController.instance.isCallActive;
  static bool get isVideo => CallController.instance.isVideo;
  static String? get avatar => CallController.instance.avatar;
}

class ChatPopupModel {
  final String id;
  final String name;
  final String avatar;
  Offset position;
  double width;
  double height;
  bool isMinimized;
  bool isMaximized;
  final TextEditingController controller;

  ChatPopupModel({
    required this.id,
    required this.name,
    required this.avatar,
    this.position = const Offset(200, 100),
    this.width = 400,
    this.height = 550,
    this.isMinimized = false,
    this.isMaximized = false,
  }) : controller = TextEditingController();
}

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key});

  static void cleanupChat(BuildContext context, String name) {
    _ChatDetailScreenState.cleanupChat(context, name);
  }

  static void endCall(BuildContext context) {
    _ChatDetailScreenState.endCall(context);
  }

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isTyping = false;
  
  // Static registry to track active popups globally
  static final List<ChatPopupModel> _activePopups = [];
  static OverlayEntry? _overlayEntry;

  static _ChatDetailScreenState? _instance;
  Timer? _callTicker;

  @override
  void initState() {
    super.initState();
    _instance = this;
    CallController.instance.addListener(_onCallStateChanged);
    _startCallTicker();
    // CLEAN UP: If we enter the main chat page, remove any active bubbles/popups for this user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        cleanupChat(context, "Tanvir Ahmed"); 
      }
    });
  }

  void _onCallStateChanged() {
    if (mounted) setState(() {});
  }

  void _startCallTicker() {
    _callTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (CallController.instance.isCallActive && mounted) {
        CallController.instance.pulse();
      }
    });
  }

  // GLOBAL END CALL: Clears state and updates UI immediately
  static void endCall(BuildContext context) {
    CallController.instance.endCall();
    if (_instance != null) {
      _instance!._triggerUpdate(context);
    }
  }

  // GLOBAL CLEANUP UTILITY: Can be called from any screen to clean bubbles/popups
  static void cleanupChat(BuildContext context, String name) {
    _activePopups.removeWhere((p) => p.name == name);
    // Trigger overlay update if someone is holding the reference, or just let the next render handle it
    // But since _overlayEntry is static, we can do it here if we have context
    if (_overlayEntry != null) {
      _instance?._triggerUpdate(context);
    }
  }

  String _formatDuration() {
    if (CallState.startTime == null) return "Connecting...";
    final duration = DateTime.now().difference(CallState.startTime!);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _triggerUpdate(BuildContext context) => _updateOverlay(context);

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    CallController.instance.removeListener(_onCallStateChanged);
    _callTicker?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  void _updateOverlay(BuildContext context) {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    
    if (_activePopups.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= 1024;

    _overlayEntry = OverlayEntry(
      builder: (context) => StatefulBuilder(
        builder: (context, setOverlayState) {
          return Stack(
            children: [
              // Render Windows ONLY on Desktop
              if (isDesktop) ..._activePopups.where((p) => !p.isMinimized).map((p) {
                final displayWidth = p.isMaximized ? screenSize.width : p.width;
                final displayHeight = p.isMaximized ? screenSize.height : p.height;
                final displayPos = p.isMaximized ? Offset.zero : p.position;

                return Positioned(
                  left: displayPos.dx,
                  top: displayPos.dy,
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      width: displayWidth,
                      height: displayHeight,
                      decoration: BoxDecoration(
                        borderRadius: p.isMaximized ? BorderRadius.zero : BorderRadius.circular(20),
                        boxShadow: p.isMaximized ? [] : [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: p.isMaximized ? BorderRadius.zero : BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Scaffold(
                              backgroundColor: isDark ? const Color(0xFF0F1117) : Colors.white,
                              body: Column(
                                children: [
                                  // Mac Title Bar (Draggable)
                                  GestureDetector(
                                    onPanStart: p.isMaximized ? (_) => windowManager.startDragging() : null,
                                    onPanUpdate: p.isMaximized ? null : (details) {
                                      setOverlayState(() {
                                        double nextX = p.position.dx + details.delta.dx;
                                        double nextY = p.position.dy + details.delta.dy;
                                        // Clamp to app boundaries
                                        p.position = Offset(
                                          nextX.clamp(0.0, screenSize.width - p.width),
                                          nextY.clamp(0.0, screenSize.height - p.height),
                                        );
                                      });
                                    },
                                    child: _buildMacTitleBar(
                                      context, 
                                      isDark, 
                                      isPopup: true, 
                                      isMaximized: p.isMaximized,
                                      onClose: () {
                                        _activePopups.remove(p);
                                        p.controller.dispose();
                                        _updateOverlay(context);
                                      },
                                      onMinimize: () {
                                        setOverlayState(() => p.isMinimized = true);
                                      },
                                      onMaximize: () {
                                        setOverlayState(() => p.isMaximized = !p.isMaximized);
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildChatHeader(
                                          context, 
                                          isDark, 
                                          Theme.of(context), 
                                          true, 
                                          p.name, 
                                          p.avatar,
                                          isPopup: true,
                                          isMaximized: p.isMaximized,
                                          onBack: () => setOverlayState(() {
                                            // When maximized, go straight to minimized bubble as requested
                                            p.isMinimized = true;
                                          }),
                                        ),
                                        Expanded(
                                          child: ListView(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            children: [
                                              _buildMessage(context, 'Chat: ${p.name}', false),
                                              _buildMessage(context, 'This is an independent window!', true),
                                            ],
                                          ),
                                        ),
                                        _buildPremiumInputArea(context, isDark, Theme.of(context), customController: p.controller, isSmall: true),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!p.isMaximized)
                              Positioned(
                                right: 0, bottom: 0,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setOverlayState(() {
                                      p.width = (p.width + details.delta.dx).clamp(320.0, screenSize.width * 0.8);
                                      p.height = (p.height + details.delta.dy).clamp(400.0, screenSize.height * 0.8);
                                    });
                                  },
                                  child: Container(width: 25, height: 25, color: Colors.transparent, child: CustomPaint(painter: _ResizeHandlePainter(isDark))),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Render Minimized Bubbles (Facebook Style)
              _buildMinimizedBubbles(context, _activePopups.where((p) => p.isMinimized).toList(), setOverlayState),
            ],
          );
        },
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMinimizedBubbles(BuildContext context, List<ChatPopupModel> minimized, StateSetter setOverlayState) {
    if (minimized.isEmpty) return const SizedBox.shrink();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final hasMore = minimized.length > 4;
    final showList = minimized.take(4).toList();
    
    return Positioned(
      right: isDesktop ? 20 : 16,
      bottom: isDesktop ? 100 : 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...showList.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: GestureDetector(
              onTap: () {
                if (isDesktop) {
                  setOverlayState(() => p.isMinimized = false);
                } else {
                  // On Mobile: Open full page and CLEAN the popup state
                  _activePopups.remove(p);
                  p.controller.dispose();
                  _updateOverlay(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatDetailScreen()));
                }
              },
              child: Container(
                width: isDesktop ? 54 : 48,
                height: isDesktop ? 54 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  image: DecorationImage(image: NetworkImage(p.avatar), fit: BoxFit.cover),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 0, top: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )),
          if (hasMore)
            GestureDetector(
              onTap: () => _showMinimizedListPopup(context, minimized, setOverlayState),
              child: Container(
                width: isDesktop ? 54 : 48,
                height: isDesktop ? 54 : 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${minimized.length - 4}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showMinimizedListPopup(BuildContext context, List<ChatPopupModel> minimized, StateSetter setOverlayState) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 350,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 20),
                      SizedBox(width: 12),
                      Text('Minimized Chats', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: minimized.length,
                    itemBuilder: (context, index) {
                      final p = minimized[index];
                      return ListTile(
                        onTap: () {
                          setOverlayState(() => p.isMinimized = false);
                          Navigator.pop(context); // Close dialog
                          if (!isDesktop) {
                            // CLEAN popup state before navigating to full page on mobile
                            _activePopups.remove(p);
                            p.controller.dispose();
                            _updateOverlay(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatDetailScreen()));
                          }
                        },
                        leading: CircleAvatar(backgroundImage: NetworkImage(p.avatar)),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const Text('10:45 AM', style: TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        subtitle: const Row(
                          children: [
                            Icon(Icons.done_all, size: 14, color: Colors.blue),
                            SizedBox(width: 4),
                            Text('Seen', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        dense: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1117) : const Color(0xFFF5F7FA),
      body: Column(
        children: [
          if (isDesktop) 
            _buildMacTitleBar(
              context, 
              isDark,
              onClose: () => Navigator.pop(context),
              onMinimize: () {
                // Minimize current main chat to a bubble
                _openNewPopup(context, isDark, "Tanvir Ahmed", 'https://i.pravatar.cc/150?u=detail');
              },
            ),
          _buildChatHeader(
            context, 
            isDark, 
            theme, 
            isDesktop, 
            "Tanvir Ahmed", 
            'https://i.pravatar.cc/150?u=detail',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                _buildMessage(context, 'Hi Tanvir, have you reviewed the latest PR?', false),
                _buildMessage(context, 'Yes, looking good so far. Just a few tweaks on the UI.', true),
                _buildMessage(context, 'Great! I will apply those changes tonight.', false),
              ],
            ),
          ),
          _buildPremiumInputArea(context, isDark, theme),
        ],
      ),
    );
  }

  Widget _buildMacTitleBar(BuildContext context, bool isDark, {
    bool isPopup = false, 
    bool isMaximized = false,
    VoidCallback? onClose,
    VoidCallback? onMinimize,
    VoidCallback? onMaximize,
  }) {
    return GestureDetector(
      onPanStart: isPopup ? null : (_) => windowManager.startDragging(),
      child: Container(
        height: 32,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A23) : const Color(0xFFEEF2F7),
          borderRadius: isPopup && !isMaximized ? const BorderRadius.vertical(top: Radius.circular(20)) : null,
          border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.08))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Row(
                children: [
                  const SizedBox(width: 10, height: 10, child: Center(child: _LiveSignalDot())),
                  const SizedBox(width: 9),
                  _AnimatedBrandingText(isDark: isDark),

                  // --- LIVE CALL STATUS IN HEADER ---
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
                                "${CallState.activeUserName} • ${_formatDuration()}",
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
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Row(
                children: [
                  _macDot(const Color(0xFFFF5F56), onClose ?? () => windowManager.close()),
                  const SizedBox(width: 9),
                  _macDot(const Color(0xFFFFBD2E), onMinimize ?? () => windowManager.minimize()),
                  const SizedBox(width: 9),
                  _macDot(const Color(0xFF28CA41), onMaximize ?? () async {
                    if (await windowManager.isMaximized()) {
                      windowManager.unmaximize();
                    } else {
                      windowManager.maximize();
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

  Widget _buildChatHeader(
    BuildContext context, 
    bool isDark, 
    ThemeData theme, 
    bool isDesktop, 
    String name, 
    String avatar, {
    bool isPopup = false,
    bool isMaximized = false,
    VoidCallback? onBack,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, isDesktop ? 10 : 40, 16, 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: onBack ?? () => Navigator.pop(context),
          ),
          CircleAvatar(radius: 16, backgroundImage: NetworkImage(avatar)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('Online', style: TextStyle(fontSize: 10, color: theme.colorScheme.primary)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, size: 22), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(name: name, avatar: avatar))),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, size: 22), 
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CallScreen(name: name, avatar: avatar, isVideo: false))),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            offset: const Offset(0, 45),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'popup') _openNewPopup(context, isDark, name, avatar);
            },
            itemBuilder: (context) => [
              if (!isPopup) 
                PopupMenuItem(
                  value: 'popup',
                  child: Row(
                    children: [
                      Icon(isDesktop ? Icons.open_in_new : Icons.bubble_chart_outlined, size: 18), 
                      const SizedBox(width: 10), 
                      Text(isDesktop ? 'Pop-up Chat' : 'Minimize to Bubble', style: const TextStyle(fontSize: 13))
                    ],
                  ),
                ),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_sweep_outlined, size: 18), SizedBox(width: 10), Text('Clear Chat', style: TextStyle(fontSize: 13))])),
            ],
          ),
        ],
      ),
    );
  }

  void _openNewPopup(BuildContext context, bool isDark, String name, String avatar) {
    if (_activePopups.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 10 windows/bubbles allowed')));
      return;
    }
    
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    // Create popup model
    final newPopup = ChatPopupModel(
      id: id, 
      name: name, 
      avatar: avatar,
      isMinimized: !isDesktop, // Minimize immediately on mobile
    );

    _activePopups.add(newPopup);
    _updateOverlay(context);

    // On mobile, after minimizing, we might want to go back or show feedback
    if (!isDesktop) {
      Navigator.pop(context); // Go back to chat list
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Chat with $name minimized to bubble'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildPremiumInputArea(BuildContext context, bool isDark, ThemeData theme, {TextEditingController? customController, bool isSmall = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isSmall ? 16 : 30),
      decoration: BoxDecoration(color: Colors.transparent, boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(height: isSmall ? 36 : 40, width: isSmall ? 36 : 40, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), shape: BoxShape.circle), child: IconButton(icon: Icon(Icons.add, size: isSmall ? 18 : 20), onPressed: () {}, color: isDark ? Colors.white70 : Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E222D) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), width: 1)),
              child: Row(children: [
                Expanded(child: TextField(controller: customController ?? _messageController, maxLines: 5, minLines: 1, onChanged: (val) => setState(() => _isTyping = val.isNotEmpty), style: TextStyle(fontSize: isSmall ? 12 : 13), decoration: InputDecoration(hintText: 'Message...', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 10)))),
                IconButton(icon: Icon(Icons.auto_awesome, size: isSmall ? 16 : 18, color: theme.colorScheme.primary.withOpacity(0.8)), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () {}),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(onTap: () {}, child: Container(height: isSmall ? 36 : 40, width: isSmall ? 36 : 40, margin: const EdgeInsets.only(bottom: 4), decoration: BoxDecoration(color: _isTyping ? theme.colorScheme.primary : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), shape: BoxShape.circle), child: Icon(_isTyping ? Icons.send : Icons.mic_none, size: isSmall ? 16 : 18, color: _isTyping ? Colors.white : (isDark ? Colors.white54 : Colors.black45)))),
        ],
      ),
    );
  }

  Widget _macDot(Color color, VoidCallback onTap) {
    return MouseRegion(cursor: SystemMouseCursors.click, child: GestureDetector(onTap: onTap, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle))));
  }

  Widget _buildMessage(BuildContext context, String text, bool isMe) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Align(alignment: isMe ? Alignment.centerRight : Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(bottom: 20), constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: isMe ? theme.colorScheme.primary : (isDark ? Colors.white.withOpacity(0.08) : Colors.white), borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isMe ? 16 : 0), bottomRight: Radius.circular(isMe ? 0 : 16))), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(text, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87), fontSize: 13)), const SizedBox(height: 4), Text('10:45 AM', style: TextStyle(color: isMe ? Colors.white60 : Colors.black38, fontSize: 9))])));
  }
}

// Global Help Widgets
class _LiveSignalDot extends StatefulWidget { const _LiveSignalDot(); @override State<_LiveSignalDot> createState() => _LiveSignalDotState(); }
class _LiveSignalDotState extends State<_LiveSignalDot> with SingleTickerProviderStateMixin { late AnimationController _ctrl; @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 333))..repeat(); } @override void dispose() { _ctrl.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _ctrl, builder: (context, _) { final colors = [const Color(0xFF00E676), const Color(0xFF00BCD4), const Color(0xFF2979FF)]; final t = _ctrl.value * colors.length; final idx = t.floor() % colors.length; return Container(decoration: BoxDecoration(color: colors[idx], shape: BoxShape.circle, boxShadow: [BoxShadow(color: colors[idx].withOpacity(0.4), blurRadius: 4, spreadRadius: 1)])); }); } }
class _AnimatedBrandingText extends StatefulWidget { final bool isDark; const _AnimatedBrandingText({required this.isDark}); @override State<_AnimatedBrandingText> createState() => _AnimatedBrandingTextState(); }
class _AnimatedBrandingTextState extends State<_AnimatedBrandingText> with SingleTickerProviderStateMixin { late AnimationController _ctrl; final List<Color> _rainbow = [const Color(0xFF00E676), const Color(0xFF00BCD4), const Color(0xFF7C4DFF), const Color(0xFFFF4081), const Color(0xFFFFAB00), const Color(0xFFFF5722), const Color(0xFF2979FF)]; @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(); } @override void dispose() { _ctrl.dispose(); super.dispose(); } @override Widget build(BuildContext context) { return AnimatedBuilder(animation: _ctrl, builder: (context, _) { final t = _ctrl.value; Color? currentColor; if (t < 0.2) { final animT = t / 0.2; final pos = animT * (_rainbow.length - 1); final idx = pos.floor(); currentColor = Color.lerp(_rainbow[idx], _rainbow[idx + 1], pos - idx); } final color = currentColor ?? (widget.isDark ? Colors.white : Colors.black); final opacity = widget.isDark ? 0.75 : 0.70; return RichText(text: TextSpan(children: [TextSpan(text: 'ebm ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withOpacity(opacity))), TextSpan(text: 'central', style: TextStyle(fontSize: 12, color: color.withOpacity(widget.isDark ? 0.4 : 0.45)))])); }); } }
class _ResizeHandlePainter extends CustomPainter { final bool isDark; _ResizeHandlePainter(this.isDark); @override void paint(Canvas canvas, Size size) { final paint = Paint()..color = isDark ? Colors.white24 : Colors.black26..strokeWidth = 1.5..strokeCap = StrokeCap.round; canvas.drawLine(Offset(size.width * 0.7, size.height), Offset(size.width, size.height * 0.7), paint); canvas.drawLine(Offset(size.width * 0.4, size.height), Offset(size.width, size.height * 0.4), paint); canvas.drawLine(Offset(size.width * 0.1, size.height), Offset(size.width, size.height * 0.1), paint); } @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false; }
