import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/region.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';
import 'ramen_shop_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────
  Region _currentRegion = Region.homeRegion;
  bool _chefMoving = false;
  bool _navigating = false;

  // ── Assets ─────────────────────────────────────────────────────────────
  Uint8List? _chefSprite;
  final Map<String, Uint8List?> _ramenBowls = {};

  // ── Animation controllers ──────────────────────────────────────────────
  late final AnimationController _chefMoveCtrl;
  late final AnimationController _floatCtrl;   // ramen bowl hover
  late final AnimationController _pulseCtrl;   // region marker pulse
  late final AnimationController _walkBobCtrl; // chef body bob while walking

  late Animation<Offset> _chefPosAnim;
  Offset _chefCurrentPos = Region.homeRegion.mapPosition;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _chefMoveCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _walkBobCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220))
      ..repeat(reverse: true);

    _chefPosAnim = Tween<Offset>(
      begin: _chefCurrentPos,
      end: _chefCurrentPos,
    ).animate(_chefMoveCtrl);

    _loadAssets();
    GameAudioService().playMapMusic();
  }

  Future<void> _loadAssets() async {
    final svc = GameAssetService();
    // Load chef sprite
    final chef = await svc.getChefSprite();
    if (mounted) setState(() => _chefSprite = chef);
    // Load ramen bowls for all regions progressively
    for (final region in Region.all) {
      final bowl = await svc.getRamenBowl(region.id);
      if (mounted) setState(() => _ramenBowls[region.id] = bowl);
    }
  }

  @override
  void dispose() {
    _chefMoveCtrl.dispose();
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _walkBobCtrl.dispose();
    super.dispose();
  }

  // ── Interaction ────────────────────────────────────────────────────────
  void _onRegionTapped(Region region) {
    if (_chefMoving || _navigating || region.id == _currentRegion.id) return;
    GameAudioService().playSfx(GameSfx.mapTap);

    final from = _chefCurrentPos;
    final to = region.mapPosition;

    _chefPosAnim = Tween<Offset>(begin: from, end: to).animate(
      CurvedAnimation(parent: _chefMoveCtrl, curve: Curves.easeInOut),
    );

    setState(() => _chefMoving = true);

    _chefMoveCtrl.forward(from: 0).whenComplete(() {
      _chefCurrentPos = to;
      setState(() {
        _chefMoving = false;
        _currentRegion = region;
      });
      GameAudioService().playSfx(GameSfx.arrive);
      _navigateToShop(region);
    });
  }

  void _navigateToShop(Region region) {
    if (_navigating) return;
    setState(() => _navigating = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (_, animation, _) =>
              RamenShopScreen(region: region),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                  parent: animation, curve: Curves.easeIn),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      )
          .then((_) {
        if (mounted) setState(() => _navigating = false);
      });
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          // Map background (ocean + islands)
          CustomPaint(
            size: size,
            painter: _JapanMapPainter(pulseValue: _pulseCtrl.value),
          ),
          // Roads layer
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, _) => CustomPaint(
              size: size,
              painter: _RoadPainter(animValue: _pulseCtrl.value),
            ),
          ),
          // Ramen bowls + region markers
          ...Region.all.map((r) => _buildRegionMarker(r, size)),
          // Chef sprite
          AnimatedBuilder(
            animation: Listenable.merge([_chefMoveCtrl, _walkBobCtrl]),
            builder: (_, _) => _buildChef(size),
          ),
          // Title HUD
          _buildHud(),
          // Mute button
          Positioned(
            top: 50,
            right: 20,
            child: _MuteButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildRegionMarker(Region region, Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseCtrl, _floatCtrl]),
      builder: (_, _) {
        final pos = region.mapPosition;
        final px = pos.dx * size.width;
        final py = pos.dy * size.height;
        final isHome = region.id == _currentRegion.id;
        final pulse = _pulseCtrl.value;
        final floatY = sin(_floatCtrl.value * pi) * 6.0;
        final bowl = _ramenBowls[region.id];
        final canTap = !_chefMoving && !_navigating && !isHome;

        return Stack(
          children: [
            // Pulse ring
            Positioned(
              left: px - 28 - pulse * 8,
              top: py - 28 - pulse * 8,
              child: Opacity(
                opacity: (1 - pulse) * 0.6,
                child: Container(
                  width: 56 + pulse * 16,
                  height: 56 + pulse * 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: region.primaryColor.withOpacity(0.8),
                        width: 2),
                  ),
                ),
              ),
            ),
            // Region marker button
            Positioned(
              left: px - 22,
              top: py - 22,
              child: GestureDetector(
                onTap: canTap ? () => _onRegionTapped(region) : null,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHome
                        ? region.primaryColor
                        : region.primaryColor.withOpacity(0.85),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.9), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: region.primaryColor.withOpacity(0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: isHome
                      ? const Icon(Icons.home, color: Colors.white, size: 22)
                      : const Icon(Icons.place, color: Colors.white, size: 20),
                ),
              ),
            ),
            // Floating ramen bowl above marker
            Positioned(
              left: px - 24,
              top: py - 76 + floatY,
              child: Column(
                children: [
                  _RamenBowlIcon(
                    imageBytes: bowl,
                    regionId: region.id,
                    size: 48,
                  ),
                  // Region label
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      region.ramenType,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: region.primaryColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Region name label
            Positioned(
              left: px - 40,
              top: py + 26,
              child: SizedBox(
                width: 80,
                child: Text(
                  region.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withOpacity(0.9),
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChef(Size size) {
    final rawPos = _chefMoving ? _chefPosAnim.value : _chefCurrentPos;
    final bobOffset = _chefMoving
        ? sin(_walkBobCtrl.value * pi * 2) * 0.008
        : 0.0;

    final px = rawPos.dx * size.width - 22;
    final py = (rawPos.dy + bobOffset) * size.height - 50;

    final facingLeft = _chefMoving &&
        _chefPosAnim.value.dx < _chefCurrentPos.dx;

    return Positioned(
      left: px,
      top: py,
      child: Transform.scale(
        scaleX: facingLeft ? -1 : 1,
        child: _chefSprite != null
            ? _GreenScreenImage(
                bytes: _chefSprite!,
                width: 44,
                height: 56,
              )
            : _FallbackChefSprite(size: 44, moving: _chefMoving),
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Color(0xEE0A1628), Color(0x000A1628)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'GOURMET GO',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _currentRegion.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
            Text(
              _currentRegion.ramenType,
              style: TextStyle(
                fontSize: 13,
                color: _currentRegion.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (!_chefMoving && !_navigating)
              Text(
                'Tap a region to travel',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            if (_chefMoving)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white60),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Travelling...',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Japan Map Painter ──────────────────────────────────────────────────────

class _JapanMapPainter extends CustomPainter {
  final double pulseValue;
  _JapanMapPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    _paintOcean(canvas, size);
    _paintIslands(canvas, size);
  }

  void _paintOcean(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A1E3D), Color(0xFF0D3055), Color(0xFF0A2545)],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    // Subtle hex/tile grid on ocean
    final gridPaint = Paint()
      ..color = const Color(0xFF1A3A5C).withOpacity(0.4)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const tileSize = 40.0;
    for (double x = 0; x < size.width; x += tileSize) {
      for (double y = 0; y < size.height; y += tileSize) {
        final cx = x + tileSize / 2;
        final cy = y + tileSize / 2;
        canvas.drawCircle(Offset(cx, cy), 1, gridPaint);
      }
    }
  }

  void _paintIslands(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Elevation shadow (draw first, offset down-right)
    const shadowOffset = Offset(5, 8);
    final shadowPaint = Paint()
      ..color = const Color(0xFF051020).withOpacity(0.6);

    for (final (path, _) in _islandData(w, h)) {
      final shifted = path.shift(shadowOffset);
      canvas.drawPath(shifted, shadowPaint);
    }

    // Island tops
    for (final (path, color) in _islandData(w, h)) {
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.95),
            Color.lerp(color, const Color(0xFF2A4A2A), 0.4)!,
          ],
        ).createShader(path.getBounds());
      canvas.drawPath(path, paint);

      // Island outline
      final outlinePaint = Paint()
        ..color = const Color(0xFF1A3A1A).withOpacity(0.8)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, outlinePaint);
    }
  }

  List<(Path, Color)> _islandData(double w, double h) {
    Offset p(double x, double y) => Offset(x * w, y * h);

    // Hokkaido
    final hokkaido = Path()
      ..moveTo(p(0.62, 0.05).dx, p(0.62, 0.05).dy)
      ..lineTo(p(0.69, 0.03).dx, p(0.69, 0.03).dy)
      ..lineTo(p(0.78, 0.05).dx, p(0.78, 0.05).dy)
      ..lineTo(p(0.83, 0.09).dx, p(0.83, 0.09).dy)
      ..lineTo(p(0.81, 0.16).dx, p(0.81, 0.16).dy)
      ..lineTo(p(0.74, 0.19).dx, p(0.74, 0.19).dy)
      ..lineTo(p(0.66, 0.19).dx, p(0.66, 0.19).dy)
      ..lineTo(p(0.61, 0.14).dx, p(0.61, 0.14).dy)
      ..lineTo(p(0.60, 0.09).dx, p(0.60, 0.09).dy)
      ..close();

    // Honshu (main island)
    final honshu = Path()
      ..moveTo(p(0.68, 0.17).dx, p(0.68, 0.17).dy)
      ..lineTo(p(0.74, 0.20).dx, p(0.74, 0.20).dy)
      ..lineTo(p(0.73, 0.27).dx, p(0.73, 0.27).dy)
      ..lineTo(p(0.68, 0.33).dx, p(0.68, 0.33).dy)
      ..lineTo(p(0.64, 0.38).dx, p(0.64, 0.38).dy)
      ..lineTo(p(0.61, 0.45).dx, p(0.61, 0.45).dy)
      ..lineTo(p(0.56, 0.50).dx, p(0.56, 0.50).dy)
      ..lineTo(p(0.50, 0.52).dx, p(0.50, 0.52).dy)
      ..lineTo(p(0.44, 0.54).dx, p(0.44, 0.54).dy)
      ..lineTo(p(0.38, 0.57).dx, p(0.38, 0.57).dy)
      ..lineTo(p(0.32, 0.58).dx, p(0.32, 0.58).dy)
      ..lineTo(p(0.28, 0.56).dx, p(0.28, 0.56).dy)
      ..lineTo(p(0.29, 0.62).dx, p(0.29, 0.62).dy)
      ..lineTo(p(0.34, 0.63).dx, p(0.34, 0.63).dy)
      ..lineTo(p(0.40, 0.62).dx, p(0.40, 0.62).dy)
      ..lineTo(p(0.46, 0.59).dx, p(0.46, 0.59).dy)
      ..lineTo(p(0.51, 0.57).dx, p(0.51, 0.57).dy)
      ..lineTo(p(0.57, 0.55).dx, p(0.57, 0.55).dy)
      ..lineTo(p(0.63, 0.51).dx, p(0.63, 0.51).dy)
      ..lineTo(p(0.67, 0.46).dx, p(0.67, 0.46).dy)
      ..lineTo(p(0.70, 0.39).dx, p(0.70, 0.39).dy)
      ..lineTo(p(0.73, 0.32).dx, p(0.73, 0.32).dy)
      ..lineTo(p(0.75, 0.25).dx, p(0.75, 0.25).dy)
      ..lineTo(p(0.73, 0.19).dx, p(0.73, 0.19).dy)
      ..close();

    // Shikoku
    final shikoku = Path()
      ..moveTo(p(0.37, 0.60).dx, p(0.37, 0.60).dy)
      ..lineTo(p(0.43, 0.58).dx, p(0.43, 0.58).dy)
      ..lineTo(p(0.48, 0.60).dx, p(0.48, 0.60).dy)
      ..lineTo(p(0.47, 0.65).dx, p(0.47, 0.65).dy)
      ..lineTo(p(0.41, 0.66).dx, p(0.41, 0.66).dy)
      ..lineTo(p(0.36, 0.64).dx, p(0.36, 0.64).dy)
      ..close();

    // Kyushu
    final kyushu = Path()
      ..moveTo(p(0.22, 0.62).dx, p(0.22, 0.62).dy)
      ..lineTo(p(0.31, 0.59).dx, p(0.31, 0.59).dy)
      ..lineTo(p(0.36, 0.62).dx, p(0.36, 0.62).dy)
      ..lineTo(p(0.35, 0.68).dx, p(0.35, 0.68).dy)
      ..lineTo(p(0.30, 0.75).dx, p(0.30, 0.75).dy)
      ..lineTo(p(0.23, 0.76).dx, p(0.23, 0.76).dy)
      ..lineTo(p(0.17, 0.72).dx, p(0.17, 0.72).dy)
      ..lineTo(p(0.18, 0.65).dx, p(0.18, 0.65).dy)
      ..close();

    return [
      (honshu, const Color(0xFF4A7C4A)),
      (hokkaido, const Color(0xFF558855)),
      (shikoku, const Color(0xFF4A7C4A)),
      (kyushu, const Color(0xFF4D7A4D)),
    ];
  }

  @override
  bool shouldRepaint(_JapanMapPainter old) => old.pulseValue != pulseValue;
}

// ── Road Painter ───────────────────────────────────────────────────────────

class _RoadPainter extends CustomPainter {
  final double animValue;
  _RoadPainter({required this.animValue});

  @override
  void paint(Canvas canvas, Size size) {
    final connections = [
      (Region.byId('hokkaido').mapPosition, Region.byId('kanto').mapPosition),
      (Region.byId('kanto').mapPosition, Region.byId('kansai').mapPosition),
      (Region.byId('kansai').mapPosition, Region.byId('kyushu').mapPosition),
    ];

    for (final (a, b) in connections) {
      _drawRoad(canvas, size, a, b);
    }
  }

  void _drawRoad(Canvas canvas, Size size, Offset a, Offset b) {
    final pa = Offset(a.dx * size.width, a.dy * size.height);
    final pb = Offset(b.dx * size.width, b.dy * size.height);

    // Road base
    final roadPaint = Paint()
      ..color = const Color(0xFFD4A84B).withOpacity(0.5)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(pa, pb, roadPaint);

    // Dashed centre line
    final dashPaint = Paint()
      ..color = const Color(0xFFFFCC66).withOpacity(0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final totalDist = (pb - pa).distance;
    const dashLen = 8.0;
    const gapLen = 10.0;
    final direction = (pb - pa) / totalDist;
    double d = (animValue * (dashLen + gapLen)) % (dashLen + gapLen);
    while (d < totalDist) {
      final start = pa + direction * d;
      final end = pa + direction * (d + dashLen).clamp(0, totalDist);
      canvas.drawLine(start, end, dashPaint);
      d += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.animValue != animValue;
}

// ── Ramen Bowl Icon ────────────────────────────────────────────────────────

class _RamenBowlIcon extends StatelessWidget {
  final Uint8List? imageBytes;
  final String regionId;
  final double size;

  const _RamenBowlIcon({
    required this.imageBytes,
    required this.regionId,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final region = Region.byId(regionId);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: region.primaryColor.withOpacity(0.15),
        border: Border.all(color: region.primaryColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: region.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1)
        ],
      ),
      child: imageBytes != null
          ? ClipOval(child: Image.memory(imageBytes!, fit: BoxFit.cover))
          : Center(
              child: Text(
                '🍜',
                style: TextStyle(fontSize: size * 0.5),
              ),
            ),
    );
  }
}

// ── Fallback chef sprite (drawn, no asset needed) ─────────────────────────

class _FallbackChefSprite extends StatelessWidget {
  final double size;
  final bool moving;
  const _FallbackChefSprite({required this.size, required this.moving});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 1.3),
      painter: _ChefIconPainter(moving: moving),
    );
  }
}

class _ChefIconPainter extends CustomPainter {
  final bool moving;
  _ChefIconPainter({required this.moving});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Toque hat
    final hatPaint = Paint()..color = const Color(0xFFF5F5F5);
    final hatBrimPaint = Paint()..color = const Color(0xFFE8E8E8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.15, h * 0.0, w * 0.7, h * 0.25),
          const Radius.circular(4)),
      hatPaint,
    );
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h * 0.23, w * 0.8, h * 0.06),
        hatBrimPaint);

    // Head
    final headPaint = Paint()..color = const Color(0xFFFDD9A0);
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), w * 0.25, headPaint);

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF333333);
    canvas.drawCircle(Offset(w * 0.38, h * 0.38), w * 0.05, eyePaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.38), w * 0.05, eyePaint);

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.42), width: w * 0.25, height: h * 0.1),
      0,
      pi,
      false,
      smilePaint,
    );

    // Body (chef coat - orange trim)
    final bodyPaint = Paint()..color = const Color(0xFFF0F0F0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.2, h * 0.6, w * 0.6, h * 0.35),
          const Radius.circular(6)),
      bodyPaint,
    );
    final trimPaint = Paint()..color = const Color(0xFFFF6B35);
    canvas.drawRect(
        Rect.fromLTWH(w * 0.2, h * 0.6, w * 0.06, h * 0.35), trimPaint);

    // Legs
    final legPaint = Paint()..color = const Color(0xFF555566);
    if (moving) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.25, h * 0.93, w * 0.2, h * 0.1),
              const Radius.circular(3)),
          legPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.55, h * 0.87, w * 0.2, h * 0.1),
              const Radius.circular(3)),
          legPaint);
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.25, h * 0.93, w * 0.2, h * 0.08),
              const Radius.circular(3)),
          legPaint);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.55, h * 0.93, w * 0.2, h * 0.08),
              const Radius.circular(3)),
          legPaint);
    }
  }

  @override
  bool shouldRepaint(_ChefIconPainter old) => old.moving != moving;
}

// ── Green-screen image widget (chroma-key removal) ────────────────────────

class _GreenScreenImage extends StatelessWidget {
  final Uint8List bytes;
  final double width;
  final double height;

  const _GreenScreenImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    // Display the raw image — Gemini can remove the green bg if the prompt
    // specifies a plain BG. For a full chroma-key we'd need a custom painter.
    return SizedBox(
      width: width,
      height: height,
      child: Image.memory(bytes, fit: BoxFit.contain),
    );
  }
}

// ── Mute button ───────────────────────────────────────────────────────────

class _MuteButton extends StatefulWidget {
  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  @override
  Widget build(BuildContext context) {
    final audio = GameAudioService();
    return GestureDetector(
      onTap: () {
        audio.toggleMute();
        setState(() {});
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.5),
          border:
              Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Icon(
          audio.muted ? Icons.volume_off : Icons.volume_up,
          color: Colors.white.withOpacity(0.8),
          size: 18,
        ),
      ),
    );
  }
}
