import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../models/dish.dart';
import '../providers/game_providers.dart';
import '../services/guide_service.dart';
import '../services/photo_source_service.dart';

/// Camera / dish-identification overlay.
///
/// The player picks a photo (camera, gallery, or demo), waits while
/// the AI identifies it, then sees the result. On success the dish
/// is added to [menuProvider]. On low confidence a starter bowl
/// picker is offered as fallback.
class CameraOverlay extends ConsumerStatefulWidget {
  const CameraOverlay({super.key, required this.game});

  final GourmetGoGame game;

  @override
  ConsumerState<CameraOverlay> createState() => _CameraOverlayState();
}

class _CameraOverlayState extends ConsumerState<CameraOverlay> {
  final _guide = GuideService();

  _Phase _phase = _Phase.pick;
  Dish? _result;
  String? _error;

  Future<void> _scan(PhotoMode mode) async {
    setState(() {
      _phase = _Phase.scanning;
      _error = null;
    });

    try {
      final bytes = await PhotoSourceService.instance.acquirePhoto(mode);
      if (!mounted) return;
      if (bytes == null) {
        setState(() => _phase = _Phase.pick);
        return;
      }
      await _identify(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.pick;
        _error = 'Something went wrong. Try again.';
      });
    }
  }

  Future<void> _identify(Uint8List bytes) async {
    try {
      final dish = await _guide.identifyAsDish(bytes);
      if (!mounted) return;
      final confidence = dish.confidence ?? 0.0;
      if (confidence >= 0.6) {
        setState(() {
          _result = dish;
          _phase = _Phase.result;
        });
      } else {
        setState(() => _phase = _Phase.fallback);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _phase = _Phase.fallback);
    }
  }

  void _addAndClose(Dish dish) {
    ref.read(menuProvider.notifier).addDish(dish);
    widget.game.closeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xEE0F0F1A),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.pick => _PickView(
              onMode: _scan,
              onClose: () => widget.game.closeCamera(),
              error: _error,
            ),
          _Phase.scanning => const _ScanningView(),
          _Phase.result => _ResultView(
              dish: _result!,
              onAdd: () => _addAndClose(_result!),
              onRetry: () => setState(() => _phase = _Phase.pick),
            ),
          _Phase.fallback => _FallbackView(
              onSelect: _addAndClose,
              onRetry: () => setState(() => _phase = _Phase.pick),
            ),
        },
      ),
    );
  }
}

enum _Phase { pick, scanning, result, fallback }

// ─── Pick view ───────────────────────────────────────────────────────────────

class _PickView extends StatelessWidget {
  const _PickView({required this.onMode, required this.onClose, this.error});

  final Future<void> Function(PhotoMode) onMode;
  final VoidCallback onClose;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Discover a Dish',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Point your camera at a bowl of ramen to add it to your menu.',
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ],
          const Spacer(),
          _ModeButton(
            icon: Icons.camera_alt,
            label: 'Take a Photo',
            subtitle: 'Use your camera',
            onTap: () => onMode(PhotoMode.camera),
          ),
          const SizedBox(height: 12),
          _ModeButton(
            icon: Icons.photo_library_outlined,
            label: 'Choose from Gallery',
            subtitle: 'Pick an existing photo',
            onTap: () => onMode(PhotoMode.gallery),
          ),
          const SizedBox(height: 12),
          _ModeButton(
            icon: Icons.auto_awesome,
            label: 'Demo Mode',
            subtitle: 'Use bundled tonkotsu photo',
            onTap: () => onMode(PhotoMode.demo),
            accent: true,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: accent
              ? Colors.deepOrange.withAlpha(40)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: accent ? Colors.deepOrange : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: accent ? Colors.deepOrange : Colors.white54),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent ? Colors.deepOrange : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style:
                      const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scanning view ───────────────────────────────────────────────────────────

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🍜', style: TextStyle(fontSize: 56)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: Colors.deepOrange),
          SizedBox(height: 20),
          Text(
            'Identifying your bowl...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'The Master is consulting the archives',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Result view ─────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.dish,
    required this.onAdd,
    required this.onRetry,
  });

  final Dish dish;
  final VoidCallback onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Dish Identified!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.deepOrange.withAlpha(100)),
            ),
            child: Column(
              children: [
                const Text('🍜', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  dish.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  dish.regionalStyle.isNotEmpty
                      ? '${dish.regionalStyle} · ${dish.brothBase}'
                      : dish.brothBase,
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 13,
                  ),
                ),
                if (dish.regionalLore != null && dish.regionalLore!.isNotEmpty)
                  ...[
                  const SizedBox(height: 12),
                  Text(
                    dish.regionalLore!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                _RarityBadge(tier: dish.rarityTier, label: dish.rarityLabel),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Add to Menu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try a different photo',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _RarityBadge extends StatelessWidget {
  const _RarityBadge({required this.tier, required this.label});

  final int tier;
  final String label;

  Color get _color => switch (tier) {
        1 => Colors.grey,
        2 => Colors.greenAccent,
        3 => Colors.purpleAccent,
        _ => Colors.amber,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withAlpha(120)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Fallback view ───────────────────────────────────────────────────────────

class _FallbackView extends StatelessWidget {
  const _FallbackView({required this.onSelect, required this.onRetry});

  final void Function(Dish) onSelect;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const Text(
            "Hmm, not sure about that one.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Pick a starter bowl to add to your menu instead:",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ...Dish.starterBowls.map(
            (dish) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelect(dish),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Text('🍜', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dish.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            dish.regionalStyle,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '¥${dish.effectivePrice}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onRetry,
            child: const Text(
              'Try a different photo',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}
