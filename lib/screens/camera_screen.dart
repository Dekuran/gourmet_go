import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/guide_service.dart';
import '../services/game_audio_service.dart';

/// Camera screen: player photographs ramen to "learn the recipe".
/// Uses GuideService (Claude) to identify the dish and generate recipe data.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  final _guide = GuideService();

  Uint8List? _photoBytes;
  String? _analysisResult;
  bool _analysing = false;

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final xFile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    GameAudioService().playSfx(GameSfx.photo);
    setState(() {
      _photoBytes = bytes;
      _analysisResult = null;
      _analysing = true;
    });
    await _analyse(bytes);
  }

  Future<void> _pickFromGallery() async {
    final xFile = await _picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (xFile == null) return;
    final bytes = await xFile.readAsBytes();
    GameAudioService().playSfx(GameSfx.photo);
    setState(() {
      _photoBytes = bytes;
      _analysisResult = null;
      _analysing = true;
    });
    await _analyse(bytes);
  }

  Future<void> _analyse(Uint8List bytes) async {
    final result = await _guide.identifyDish(bytes);
    if (mounted) {
      setState(() {
        _analysisResult = result;
        _analysing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A12),
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildViewfinder()),
                _buildControls(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Capture the Ramen',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo or placeholder
              if (_photoBytes != null)
                Image.memory(_photoBytes!, fit: BoxFit.cover)
              else
                _buildPlaceholder(),
              // Scanning overlay while analysing
              if (_analysing) _buildScanOverlay(),
              // Result overlay
              if (_analysisResult != null && !_analysing)
                _buildResultOverlay(),
              // Corner brackets
              _buildCornerBrackets(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFF0D1E35),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, _) => Opacity(
              opacity: 0.4 + _pulseCtrl.value * 0.4,
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.white38,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Point at the ramen bowl',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanOverlay() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, _) {
        return Stack(
          children: [
            // Dim overlay
            Container(color: Colors.black.withAlpha(100)),
            // Scan line
            Positioned(
              top: _pulseCtrl.value *
                  (MediaQuery.of(context).size.height * 0.55),
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.cyanAccent.withAlpha(200),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Loading text
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.cyanAccent,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Analysing dish...',
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(230), Colors.transparent],
          ),
        ),
        child: Text(
          _analysisResult ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCornerBrackets() {
    return CustomPaint(
      painter: _BracketPainter(
        color: _analysisResult != null
            ? Colors.greenAccent
            : const Color(0xFF4A8FD9),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        children: [
          // Shoot button
          GestureDetector(
            onTap: _analysing ? null : _takePhoto,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _analysing
                    ? Colors.grey.withAlpha(100)
                    : Colors.white,
                boxShadow: _analysing
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.white.withAlpha(80),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
              ),
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _analysing
                      ? Colors.grey.withAlpha(80)
                      : const Color(0xFFFF6B35),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Gallery option
          TextButton.icon(
            onPressed: _analysing ? null : _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined,
                color: Colors.white54, size: 18),
            label: const Text(
              'Choose from gallery',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          // Show full analysis if available
          if (_analysisResult != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showFullAnalysis(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.greenAccent.withAlpha(120), width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.greenAccent, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Dish identified! View details',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showFullAnalysis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1E35),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AnalysisSheet(text: _analysisResult ?? ''),
    );
  }
}

// ── Corner bracket painter ─────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Color color;
  _BracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 24.0;
    final corners = [
      (Offset.zero, true, true),
      (Offset(size.width, 0), false, true),
      (Offset(0, size.height), true, false),
      (Offset(size.width, size.height), false, false),
    ];

    for (final (corner, isLeft, isTop) in corners) {
      final xDir = isLeft ? 1.0 : -1.0;
      final yDir = isTop ? 1.0 : -1.0;
      canvas.drawLine(corner, corner + Offset(xDir * len, 0), paint);
      canvas.drawLine(corner, corner + Offset(0, yDir * len), paint);
    }
  }

  @override
  bool shouldRepaint(_BracketPainter old) => old.color != color;
}

// ── Analysis bottom sheet ─────────────────────────────────────────────────

class _AnalysisSheet extends StatelessWidget {
  final String text;
  const _AnalysisSheet({required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Dish Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
