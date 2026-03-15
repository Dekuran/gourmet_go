import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';
import 'visual_novel_screen.dart';

/// Shows the exterior/entrance of a regional ramen shop.
/// The chef sprite shuffles in from the side, then the player can enter.
class RamenShopScreen extends StatefulWidget {
  final Region region;
  const RamenShopScreen({super.key, required this.region});

  @override
  State<RamenShopScreen> createState() => _RamenShopScreenState();
}

class _RamenShopScreenState extends State<RamenShopScreen>
    with TickerProviderStateMixin {
  // ── Assets ─────────────────────────────────────────────────────────────
  Uint8List? _shopBackground;
  Uint8List? _chefSprite;

  // ── Animation ──────────────────────────────────────────────────────────
  late final AnimationController _chefEnterCtrl;
  late final AnimationController _signBobCtrl;
  late final AnimationController _steamCtrl;

  late final Animation<Offset> _chefSlide;
  late final Animation<double> _chefFade;

  bool _chefArrived = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();

    _chefEnterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _signBobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _steamCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _chefSlide = Tween<Offset>(
      begin: const Offset(-1.5, 0),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _chefEnterCtrl, curve: Curves.easeOutBack));

    _chefFade = CurvedAnimation(parent: _chefEnterCtrl, curve: Curves.easeIn);

    // Switch to shop music, then start chef entrance
    GameAudioService().playShopMusic();
    Future.delayed(const Duration(milliseconds: 400), _startChefEntrance);

    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final svc = GameAssetService();
    final bg = await svc.getShopBackground(widget.region.id);
    final chef = await svc.getChefSprite();
    if (mounted) {
      setState(() {
        _shopBackground = bg;
        _chefSprite = chef;
      });
    }
  }

  void _startChefEntrance() {
    GameAudioService().playSfx(GameSfx.chefWalk);
    _chefEnterCtrl.forward().whenComplete(() {
      GameAudioService().playSfx(GameSfx.arrive);
      if (mounted) setState(() => _chefArrived = true);
    });
  }

  void _enterShop() {
    if (_navigating) return;
    setState(() => _navigating = true);
    GameAudioService().playSfx(GameSfx.doorOpen);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, _) =>
              VisualNovelScreen(region: widget.region),
          transitionsBuilder: (_, animation, _, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      ).then((_) {
        if (mounted) setState(() => _navigating = false);
      });
    });
  }

  @override
  void dispose() {
    _chefEnterCtrl.dispose();
    _signBobCtrl.dispose();
    _steamCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final region = widget.region;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          // Background
          _buildBackground(size),
          // Steam particles
          AnimatedBuilder(
            animation: _steamCtrl,
            builder: (_, _) => CustomPaint(
              size: size,
              painter: _SteamPainter(animValue: _steamCtrl.value),
            ),
          ),
          // Shop sign / facade overlay
          _buildShopFacade(region),
          // Chef sprite entering
          _buildChefEntrance(size),
          // Enter button (appears after chef arrives)
          if (_chefArrived) _buildEnterPrompt(region),
          // Back button
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
              onPressed: () {
                GameAudioService().playMapMusic();
                Navigator.of(context).pop();
              },
            ),
          ),
          // Region name header
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  region.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
                Text(
                  region.ramenType,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: region.primaryColor,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(Size size) {
    if (_shopBackground != null) {
      return Positioned.fill(
        child: Image.memory(
          _shopBackground!,
          fit: BoxFit.cover,
        ),
      );
    }
    // Fallback gradient background
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              widget.region.primaryColor.withAlpha(200),
              const Color(0xFF0A1628),
            ],
          ),
        ),
        child: _buildFallbackShopScene(),
      ),
    );
  }

  Widget _buildFallbackShopScene() {
    return Stack(
      children: [
        // Floor
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 120,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A1A0A), Color(0xFF1A0E05)],
              ),
            ),
          ),
        ),
        // Counter silhouette
        Positioned(
          bottom: 80,
          left: 40,
          right: 40,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF3A2A15),
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
          ),
        ),
        // Hanging lanterns
        ...List.generate(4, (i) {
          return Positioned(
            top: 80,
            left: 60.0 + i * 80,
            child: _buildLantern(widget.region.primaryColor),
          );
        }),
      ],
    );
  }

  Widget _buildLantern(Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 20,
          color: Colors.brown.shade400,
        ),
        Container(
          width: 28,
          height: 40,
          decoration: BoxDecoration(
            color: color.withAlpha(200),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(120),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShopFacade(Region region) {
    return AnimatedBuilder(
      animation: _signBobCtrl,
      builder: (_, _) {
        final bob = (_signBobCtrl.value - 0.5) * 6;
        return Positioned(
          top: 120 + bob,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(180),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: region.primaryColor.withAlpha(180), width: 2),
                boxShadow: [
                  BoxShadow(
                      color: region.primaryColor.withAlpha(80),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🍜  ${region.ramenType}  🍜',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: region.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    region.ramenDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChefEntrance(Size size) {
    return SlideTransition(
      position: _chefSlide,
      child: FadeTransition(
        opacity: _chefFade,
        child: Positioned(
          bottom: 100,
          left: size.width * 0.15,
          child: _chefSprite != null
              ? Image.memory(
                  _chefSprite!,
                  width: 80,
                  height: 100,
                  fit: BoxFit.contain,
                )
              : CustomPaint(
                  size: const Size(80, 100),
                  painter: _ChefFallbackPainter(),
                ),
        ),
      ),
    );
  }

  Widget _buildEnterPrompt(Region region) {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedScale(
          scale: _navigating ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: GestureDetector(
            onTap: _enterShop,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [region.primaryColor, region.secondaryColor],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: region.primaryColor.withAlpha(120),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter Shop',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Steam particle painter ─────────────────────────────────────────────────

class _SteamPainter extends CustomPainter {
  final double animValue;
  _SteamPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = [0.2, 0.5, 0.8];
    for (int i = 0; i < rng.length; i++) {
      final phase = (animValue + i * 0.33) % 1.0;
      final x = size.width * rng[i];
      final y = size.height * (0.9 - phase * 0.4);
      final radius = 8 + phase * 20;
      final opacity = (1 - phase) * 0.15;
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Colors.white.withAlpha((opacity * 255).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
  }

  @override
  bool shouldRepaint(_SteamPainter old) => old.animValue != animValue;
}

// ── Fallback chef painter ─────────────────────────────────────────────────

class _ChefFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Hat
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.15, 0, w * 0.7, h * 0.25),
          const Radius.circular(4)),
      Paint()..color = const Color(0xFFF5F5F5),
    );
    // Head
    canvas.drawCircle(Offset(w * 0.5, h * 0.38),
        w * 0.25, Paint()..color = const Color(0xFFFDD9A0));
    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.56, w * 0.6, h * 0.38),
          const Radius.circular(6)),
      Paint()..color = const Color(0xFFF0F0F0),
    );
    // Orange trim
    canvas.drawRect(
        Rect.fromLTWH(w * 0.2, h * 0.56, w * 0.07, h * 0.38),
        Paint()..color = const Color(0xFFFF6B35));
  }

  @override
  bool shouldRepaint(_) => false;
}
