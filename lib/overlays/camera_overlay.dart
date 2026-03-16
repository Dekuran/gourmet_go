import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../gourmet_go_app.dart';
import '../models/dish.dart';
import '../providers/game_providers.dart';
import '../services/debug_logger.dart';
import '../services/ftue_service.dart';
import '../services/game_audio_service.dart';
import '../services/guide_service.dart';
import '../services/photo_source_service.dart';
import '../services/ramen_api_service.dart';
import 'ftue_shared_state.dart';

/// Camera overlay — photo capture + AI dish identification.
///
/// Offers three modes: camera, gallery upload, or demo (bundled image).
/// After the photo is taken, it runs through GuideService for identification,
/// matches against RamenApiService for pricing, then transitions to the
/// dish reveal overlay.
class CameraOverlay extends ConsumerStatefulWidget {
  const CameraOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  ConsumerState<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends ConsumerState<CameraOverlay> {
  static final _log = DebugLogger.instance;
  static final _audio = GameAudioService();
  static final _photo = PhotoSourceService.instance;
  static final _guide = GuideService();
  static final _ramenApi = RamenApiService.instance;

  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    GourmetGoApp.unlockOrientation();
  }

  @override
  void dispose() {
    GourmetGoApp.lockToLandscape();
    super.dispose();
  }

  Future<void> _captureAndIdentify(PhotoMode mode) async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // 1. Acquire photo
      final bytes = await _photo.acquirePhoto(mode);
      if (bytes == null) {
        setState(() {
          _processing = false;
          _error = 'No photo selected';
        });
        return;
      }

      await _audio.playSfx(GameSfx.photo);

      // 2. Identify the dish via Claude AI
      _log.logInfo('Camera', 'Identifying dish...');
      Dish dish;
      try {
        dish = await _guide.identifyAsDish(bytes);
        // Low confidence means unrecognised — fall back on web
        if ((dish.confidence ?? 0.0) < 0.3) {
          throw Exception('Low confidence: ${dish.confidence}');
        }
      } catch (e) {
        // On web, Claude API is blocked by CORS. Use fixture dish for demo.
        if (kIsWeb) {
          _log.logInfo('Camera', 'API failed on web, using fixture dish');
          dish = _fixtureTonkotsu;
        } else {
          setState(() {
            _processing = false;
            _error = 'Could not identify the dish. Try again!';
          });
          return;
        }
      }

      // 3. Match to variety catalogue for pricing
      final price = await _ramenApi.getPrice(dish.varietyId);
      final pricedDish = dish.copyWith(price: price);

      // 4. Add to menu
      ref.read(menuProvider.notifier).addDish(pricedDish);

      // 5. Unlock the region based on broth type
      final regionId = _brothToRegion(pricedDish.brothBase);
      ref.read(regionUnlockProvider.notifier).unlock(regionId);

      // 6. Save as first dish if FTUE
      final isFirstLaunch = await FtueService.instance.isFirstLaunch();
      if (isFirstLaunch) {
        await FtueService.instance.saveFirstDish(pricedDish);
        await FtueService.instance.saveStep(FtueStep.dishReveal);
      }

      _log.logSuccess('Camera', 'identify', '${pricedDish.name} ($price credits)');

      // 7. Transition to dish reveal
      if (mounted) {
        widget.game.hideOverlay(GameOverlay.camera);
        // Store dish + photo for the reveal overlay to read
        FtueSharedState.instance
          ..lastDish = pricedDish
          ..lastPhotoBytes = bytes;
        widget.game.showOverlay(GameOverlay.dishReveal);
      }
    } catch (e) {
      _log.logError('Camera', 'captureAndIdentify', '$e');
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Something went wrong: $e';
        });
      }
    }
  }

  /// Fixture dish used when Claude API is unreachable (e.g. CORS on web).
  static final _fixtureTonkotsu = Dish(
    varietyId: 'tonkotsu_hakata',
    name: 'Hakata Tonkotsu Ramen',
    regionalStyle: 'Hakata-style',
    brothBase: 'tonkotsu',
    rarityTier: 2,
    regionalLore: 'Born in the yatai stalls of Fukuoka\'s Nakasu district, '
        'this milky-white pork bone broth is simmered for 12+ hours.',
    confidence: 0.95,
  );


  String _brothToRegion(String brothBase) => switch (brothBase.toLowerCase()) {
        'tonkotsu' => 'kyushu',
        'shoyu' => 'kanto',
        'miso' => 'hokkaido',
        'shio' => 'kansai',
        _ => 'kanto',
      };

  // Dreamy anime pastel palette
  static const _warmPink = Color(0xFFE8A0BF);     // soft cherry blossom
  static const _softGold = Color(0xFFD4A574);      // warm golden miso
  static const _mistyLavender = Color(0xFFB8A9C9); // twilight lavender
  static const _deepWarm = Color(0xFF3D2B1F);      // dark rich wood

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xF01A0A05), // dark kitchen top
            Color(0xF02D1508), // warm brown mid
            Color(0xF01A0A05), // dark kitchen bottom
          ],
        ),
      ),
      child: SafeArea(
        child: _processing ? _buildProcessing() : _buildChooser(),
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: _warmPink,
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'The Master is studying your bowl...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          const Text('🍜', style: TextStyle(fontSize: 48)),
        ],
      ),
    );
  }

  Widget _buildChooser() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decorative top
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [
                  Color(0x40E8A0BF),
                  Color(0x10E8A0BF),
                ],
              ),
              border: Border.all(
                color: _warmPink.withAlpha(60),
                width: 2,
              ),
            ),
            child: const Center(
              child: Text('📸', style: TextStyle(fontSize: 36)),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Show me a bowl of ramen!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo, pick from your gallery,\nor try our demo bowl.',
            style: TextStyle(
              color: Colors.white.withAlpha(150),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Camera button — cherry blossom pink
          _ActionButton(
            icon: Icons.camera_alt_rounded,
            label: 'Take Photo',
            color: _warmPink,
            textColor: _deepWarm,
            onTap: () => _captureAndIdentify(PhotoMode.camera),
          ),
          const SizedBox(height: 14),

          // Gallery button — warm golden miso
          _ActionButton(
            icon: Icons.photo_library_rounded,
            label: 'Choose from Gallery',
            color: _softGold,
            textColor: _deepWarm,
            onTap: () => _captureAndIdentify(PhotoMode.gallery),
          ),
          const SizedBox(height: 14),

          // Demo button — misty lavender
          _ActionButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Use Demo Bowl  🍜',
            color: _mistyLavender,
            textColor: _deepWarm,
            onTap: () => _captureAndIdentify(PhotoMode.demo),
          ),

          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0x30FF6B6B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0x40FF6B6B),
                ),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFFFADAD),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: color.withAlpha(60),
        ),
      ),
    );
  }
}
