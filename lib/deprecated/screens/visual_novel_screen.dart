import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';
import 'camera_screen.dart';

/// Visual-novel style screen: chef looks at the player and delivers dialogue
/// with typewriter text and optional ElevenLabs voice narration.
class VisualNovelScreen extends StatefulWidget {
  final Region region;
  const VisualNovelScreen({super.key, required this.region});

  @override
  State<VisualNovelScreen> createState() => _VisualNovelScreenState();
}

class _VisualNovelScreenState extends State<VisualNovelScreen>
    with TickerProviderStateMixin {
  // ── Assets ─────────────────────────────────────────────────────────────
  Uint8List? _shopBackground;
  Uint8List? _chefPortrait;

  // ── Dialogue typewriter ────────────────────────────────────────────────
  late final AnimationController _typeCtrl;
  late final Animation<int> _charCount;

  bool _voicePlaying = false;
  bool _dialogueDone = false;
  bool _voiceStarted = false;

  // ── Portrait entrance ──────────────────────────────────────────────────
  late final AnimationController _portraitCtrl;
  late final Animation<Offset> _portraitSlide;
  late final Animation<double> _portraitFade;

  // ── Idle bob ───────────────────────────────────────────────────────────
  late final AnimationController _idleBobCtrl;

  String get _dialogue => widget.region.arrivalQuote;

  @override
  void initState() {
    super.initState();

    _typeCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _dialogue.length * 40),
    );
    _charCount = IntTween(begin: 0, end: _dialogue.length)
        .animate(CurvedAnimation(parent: _typeCtrl, curve: Curves.linear))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _dialogueDone = true);
        }
      });

    _portraitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _portraitSlide = Tween<Offset>(
      begin: const Offset(-0.3, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _portraitCtrl, curve: Curves.easeOutCubic));
    _portraitFade = CurvedAnimation(
        parent: _portraitCtrl, curve: Curves.easeIn);

    _idleBobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _init();
  }

  Future<void> _init() async {
    // Load assets in parallel
    final svc = GameAssetService();
    final results = await Future.wait([
      svc.getShopBackground(widget.region.id),
      svc.getChefPortrait(),
    ]);
    if (mounted) {
      setState(() {
        _shopBackground = results[0];
        _chefPortrait = results[1];
      });
    }

    // Start animations
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    _portraitCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    _typeCtrl.forward();

    // Speak once (non-blocking)
    if (!_voiceStarted) {
      _voiceStarted = true;
      setState(() => _voicePlaying = true);
      GameAudioService().speakLine(_dialogue).then((_) {
        if (mounted) setState(() => _voicePlaying = false);
      });
    }
  }

  void _skipToEnd() {
    if (!_dialogueDone) {
      _typeCtrl.value = 1.0;
      setState(() => _dialogueDone = true);
    }
  }

  void _goToCamera() {
    GameAudioService().playSfx(GameSfx.photo);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _portraitCtrl.dispose();
    _idleBobCtrl.dispose();
    GameAudioService().stopVoice();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final region = widget.region;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: GestureDetector(
        onTap: _dialogueDone ? null : _skipToEnd,
        child: Stack(
          children: [
            // Blurred background
            _buildBackground(size),
            // Vignette overlay
            _buildVignette(),
            // Chef portrait (left side)
            _buildPortrait(size, region),
            // Dialogue box (bottom)
            _buildDialogueBox(size, region),
            // Back button
            Positioned(
              top: 50,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
                onPressed: () {
                  GameAudioService().stopVoice();
                  Navigator.of(context).pop();
                },
              ),
            ),
            // Voice indicator
            if (_voicePlaying)
              Positioned(
                top: 54,
                right: 20,
                child: _VoiceIndicator(color: region.primaryColor),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(Size size) {
    if (_shopBackground != null) {
      return Positioned.fill(
        child: ColorFiltered(
          colorFilter: ColorFilter.matrix([
            0.5, 0, 0, 0, 0,
            0, 0.5, 0, 0, 0,
            0, 0, 0.5, 0, 0,
            0, 0,   0, 1, 0,
          ]),
          child: Image.memory(
            _shopBackground!,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.region.primaryColor.withAlpha(60),
              const Color(0xFF050A12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVignette() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [Colors.transparent, Colors.black.withAlpha(160)],
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait(Size size, Region region) {
    return AnimatedBuilder(
      animation: Listenable.merge([_portraitCtrl, _idleBobCtrl]),
      builder: (_, _) {
        final bob = sin(_idleBobCtrl.value * pi) * 6;
        return Positioned(
          left: -size.width * 0.05,
          bottom: size.height * 0.28 + bob,
          child: SlideTransition(
            position: _portraitSlide,
            child: FadeTransition(
              opacity: _portraitFade,
              child: _chefPortrait != null
                  ? Image.memory(
                      _chefPortrait!,
                      height: size.height * 0.55,
                      fit: BoxFit.contain,
                    )
                  : _FallbackPortrait(
                      height: size.height * 0.55,
                      color: region.primaryColor,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogueBox(Size size, Region region) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        constraints: BoxConstraints(minHeight: size.height * 0.28),
        decoration: BoxDecoration(
          color: const Color(0xF0050A14),
          border: Border(
            top: BorderSide(color: region.primaryColor.withAlpha(180), width: 2),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Character nameplate
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: region.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Chef Guide',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Typewriter text
            AnimatedBuilder(
              animation: _charCount,
              builder: (_, _) {
                final visible = _dialogue.substring(
                    0, _charCount.value.clamp(0, _dialogue.length));
                return Text(
                  visible,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    height: 1.55,
                    letterSpacing: 0.2,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            // Action row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Skip hint (while typing)
                if (!_dialogueDone)
                  Text(
                    'Tap to skip',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(100),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                // Camera button (when done)
                if (_dialogueDone)
                  GestureDetector(
                    onTap: _goToCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            region.primaryColor,
                            region.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: region.primaryColor.withAlpha(120),
                            blurRadius: 14,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Take Photo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Voice playing indicator ────────────────────────────────────────────────

class _VoiceIndicator extends StatefulWidget {
  final Color color;
  const _VoiceIndicator({required this.color});

  @override
  State<_VoiceIndicator> createState() => _VoiceIndicatorState();
}

class _VoiceIndicatorState extends State<_VoiceIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
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
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_ctrl.value + i * 0.3) % 1.0;
            final barH = 8.0 + phase * 14;
            return Container(
              width: 4,
              height: barH,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Fallback portrait (drawn chef, no asset) ──────────────────────────────

class _FallbackPortrait extends StatelessWidget {
  final double height;
  final Color color;
  const _FallbackPortrait({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.65,
      height: height,
      child: CustomPaint(painter: _PortraitPainter(accentColor: color)),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  final Color accentColor;
  _PortraitPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Toque
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.1, h * 0.02, w * 0.8, h * 0.2),
          const Radius.circular(6)),
      Paint()..color = const Color(0xFFF5F5F5),
    );
    canvas.drawRect(
        Rect.fromLTWH(w * 0.05, h * 0.21, w * 0.9, h * 0.05),
        Paint()..color = const Color(0xFFE0E0E0));

    // Head (bigger for portrait)
    canvas.drawCircle(
        Offset(w * 0.5, h * 0.38),
        w * 0.32,
        Paint()..color = const Color(0xFFFDD9A0));

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF2A1A0A);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.36, h * 0.36), width: 16, height: 18),
        eyePaint);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(w * 0.64, h * 0.36), width: 16, height: 18),
        eyePaint);
    // Pupils
    canvas.drawCircle(Offset(w * 0.37, h * 0.365), 5,
        Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.65, h * 0.365), 5,
        Paint()..color = Colors.white);

    // Smile
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.42), width: w * 0.3, height: h * 0.1),
      0,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF8B4513)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    // Rosy cheeks
    canvas.drawCircle(Offset(w * 0.24, h * 0.41), 8,
        Paint()..color = Colors.pink.withAlpha(80));
    canvas.drawCircle(Offset(w * 0.76, h * 0.41), 8,
        Paint()..color = Colors.pink.withAlpha(80));

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.05, h * 0.65, w * 0.9, h * 0.35),
          const Radius.circular(10)),
      Paint()..color = const Color(0xFFF5F5F5),
    );
    // Orange accent stripe
    canvas.drawRect(
        Rect.fromLTWH(w * 0.05, h * 0.65, w * 0.1, h * 0.35),
        Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(_) => false;
}
