import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/glass_card.dart';
import 'mail_provider.dart';
import 'dart:async';

class MailAutomationScreen extends ConsumerStatefulWidget {
  const MailAutomationScreen({super.key});

  @override
  ConsumerState<MailAutomationScreen> createState() => _MailAutomationScreenState();
}

class _MailAutomationScreenState extends ConsumerState<MailAutomationScreen> with TickerProviderStateMixin {
  final _promptController = TextEditingController();
  final _guidelinesController = TextEditingController(
    text: "Company: EBM Central\nRules: Be professional yet friendly. Use formal sign-offs.\nStyle: Concise and result-oriented."
  );
  
  bool _isGenerating = false;
  String? _finalSubject;
  String? _finalBody;
  
  String _displayedBody = "";
  int _charIndex = 0;
  Timer? _typewriterTimer;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _guidelinesController.dispose();
    _typewriterTimer?.cancel();
    _glowController.dispose();
    super.dispose();
  }

  void _startTypewriter(String fullText) {
    _displayedBody = "";
    _charIndex = 0;
    _typewriterTimer?.cancel();
    
    // FASTER TYPEWRITER (10ms delay for snappier feel)
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (_charIndex < fullText.length) {
        if (mounted) {
          setState(() {
            _displayedBody += fullText[_charIndex];
            _charIndex++;
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _generateAI() async {
    if (_promptController.text.isEmpty) return;
    
    setState(() {
      _isGenerating = true;
      _displayedBody = "";
      _finalSubject = null;
    });

    try {
      // In production, we send BOTH prompt and guidelines to backend
      // await ref.read(mailServiceProvider).generateAiContent(_promptController.text, _guidelinesController.text);
      
      await Future.delayed(const Duration(seconds: 1)); // Faster "thinking" too
      
      final mockSubject = "Proposal: Creative Solutions for ${_promptController.text}";
      final mockBody = "Dear Partner,\n\n"
          "I hope this email finds you well. Regarding your request about '${_promptController.text}', "
          "our team has brainstormed several innovative approaches to maximize your impact. "
          "As per EBM Central guidelines, we prioritize transparency and speed in our communication.\n\n"
          "We believe that a synergy between our core expertise and your vision will yield extraordinary results.\n\n"
          "Best Regards,\n"
          "The EBM Team";

      setState(() {
        _isGenerating = false;
        _finalSubject = mockSubject;
        _finalBody = mockBody;
      });
      
      _startTypewriter(mockBody);
      
    } catch (e) {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text("Mail Hub: AI & Automation", 
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
        ),
      ),
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(text: "AI Assistant"),
                Tab(text: "Brand Guidelines"),
                Tab(text: "Automation"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAiTab(context),
                  _buildGuidelinesTab(context),
                  _buildAutomationTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, "WHAT ARE WE WRITING TODAY?"),
          const SizedBox(height: 16),
          GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Describe your email objective...",
                hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(24),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildGenerateButton(theme),
          
          if (_isGenerating || _finalSubject != null) ...[
            const SizedBox(height: 40),
            _buildSectionHeader(context, "REAL-TIME AI COMPOSITION"),
            const SizedBox(height: 16),
            _buildGeneratedContentCard(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidelinesTab(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context, "AI BRAND GUIDELINES"),
          const SizedBox(height: 12),
          Text("These rules will be sent to the AI with every prompt to ensure consistency.", 
            style: theme.textTheme.bodySmall
          ),
          const SizedBox(height: 20),
          GlassCard(
            padding: EdgeInsets.zero,
            child: TextField(
              controller: _guidelinesController,
              maxLines: 15,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              decoration: InputDecoration(
                hintText: "Enter company rules, tone of voice, forbidden words, etc.",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(24),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guidelines Saved!")));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("SAVE BRAND GUIDELINES"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateButton(ThemeData theme) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isGenerating ? [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3 * _glowController.value),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateAI,
            icon: _isGenerating 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.bolt_rounded, size: 20),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 22),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            label: Text(_isGenerating ? "AI IS COMPOSING..." : "GENERATE WITH BRAND VOICE", 
              style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneratedContentCard(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_finalSubject != null)
            Text(_finalSubject!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
          
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          
          if (_isGenerating)
            _buildPulseLoader(theme)
          else
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  theme.colorScheme.onSurface,
                  theme.colorScheme.primary.withOpacity(0.8),
                  theme.colorScheme.onSurface,
                ],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                transform: GradientRotation(_glowController.value * 6),
              ).createShader(bounds),
              child: Text(
                _displayedBody,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7, letterSpacing: 0.2),
              ),
            ),
          
          if (!_isGenerating && _displayedBody.isNotEmpty) ...[
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {}, 
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    label: const Text("COPY"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {}, 
                    icon: const Icon(Icons.send_rounded, size: 18),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                      foregroundColor: theme.colorScheme.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    label: const Text("USE DRAFT"),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPulseLoader(ThemeData theme) {
    return Column(
      children: List.generate(3, (index) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: LinearProgressIndicator(
            backgroundColor: theme.colorScheme.outlineVariant.withOpacity(0.1),
            color: theme.colorScheme.primary.withOpacity(0.2),
            minHeight: 10,
          ),
        )
      ),
    );
  }

  Widget _buildAutomationTab(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(context, "ACTIVE SCHEDULES"),
              IconButton(onPressed: (){}, icon: const Icon(Icons.add_circle_outline_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 2,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return GlassCard(
                  padding: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(Icons.schedule_rounded, color: theme.colorScheme.primary),
                    title: Text(index == 0 ? "Weekly Update" : "Daily Sync", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(index == 0 ? "Mon, Wed at 09:00 AM" : "Every day at 05:00 PM"),
                    trailing: Switch(value: true, onChanged: (v){}, activeColor: theme.colorScheme.primary),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(width: 4, height: 16, decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: theme.colorScheme.primary.withOpacity(0.8)),
        ),
      ],
    );
  }
}
