import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
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

      // 2. Identify the dish
      _log.logInfo('Camera', 'Identifying dish...');
      final dish = await _guide.identifyAsDish(bytes);

      if (dish == null) {
        setState(() {
          _processing = false;
          _error = 'Could not identify the dish. Try again!';
        });
        return;
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

      _log.logSuccess('Camera', 'identify', '${pricedDish.name} (¥$price)');

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


  String _brothToRegion(String brothBase) => switch (brothBase.toLowerCase()) {
        'tonkotsu' => 'kyushu',
        'shoyu' => 'kanto',
        'miso' => 'hokkaido',
        'shio' => 'kansai',
        _ => 'kanto',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withAlpha(220),
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
          const CircularProgressIndicator(color: Colors.deepOrange),
          const SizedBox(height: 20),
          Text(
            'Identifying your ramen...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '🍜',
            style: TextStyle(fontSize: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildChooser() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.deepOrange,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'Show me a bowl of ramen!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Take a photo, pick from gallery, or use our demo bowl.',
            style: TextStyle(color: Colors.white60, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Camera button
          _ActionButton(
            icon: Icons.camera_alt,
            label: 'Take Photo',
            color: Colors.deepOrange,
            onTap: () => _captureAndIdentify(PhotoMode.camera),
          ),
          const SizedBox(height: 12),

          // Gallery button
          _ActionButton(
            icon: Icons.photo_library,
            label: 'Choose from Gallery',
            color: Colors.amber.shade700,
            onTap: () => _captureAndIdentify(PhotoMode.gallery),
          ),
          const SizedBox(height: 12),

          // Demo button
          _ActionButton(
            icon: Icons.auto_awesome,
            label: 'Use Demo Bowl 🍜',
            color: Colors.teal,
            onTap: () => _captureAndIdentify(PhotoMode.demo),
          ),

          if (_error != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
