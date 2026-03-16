import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../game/gourmet_go_game.dart';
import '../game/scenes/shop_scene.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../providers/game_providers.dart';
import '../services/debug_logger.dart';
import '../services/ftue_service.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';
import '../services/guide_service.dart';
import '../services/seedance_service.dart';
import '../services/tripo_service.dart';
import 'ftue_shared_state.dart';

/// Dish reveal overlay — the AI showcase moment.
///
/// Multi-phase visual novel reveal:
///   Phase 1: Cooking video plays + sous chef describes the dish (short)
///   Phase 2: Dish card animates in with recipe results
///   Phase 3: "Added to Menu!" — tap to go to restaurant kitchen
///
/// Kitchen background, sous chef portrait, video window.
/// Transitions to the kitchen/restaurant view (NOT map) after FTUE.
class DishRevealOverlay extends ConsumerStatefulWidget {
  const DishRevealOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  ConsumerState<DishRevealOverlay> createState() => _DishRevealOverlayState();
}

class _DishRevealOverlayState extends ConsumerState<DishRevealOverlay>
    with TickerProviderStateMixin {
  static final _log = DebugLogger.instance;
  static final _audio = GameAudioService();
  static final _guide = GuideService();
  static final _tripo = TripoService();
  static final _seedance = SeedanceService();

  // Data from camera overlay via FtueSharedState
  Dish? _dish;

  // AI pipeline state
  Recipe? _recipe;
  bool _recipeLoading = true;

  String? _glbUrl;
  bool _tripoLoading = true;

  String? _videoUrl;
  bool _seedanceLoading = true;

  // Video player (shows pre-seeded video, then AI-generated video)
  VideoPlayerController? _videoController;

  // Sous chef dialogue state
  String _chefLine = 'Let me take a closer look at this bowl...';
  SousChefMood _chefMood = SousChefMood.thinking;

  // Reveal phase: 0=loading, 1=dish card visible, 2=all done
  int _phase = 0;

  // Animations
  late AnimationController _revealAnim;
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _dish = FtueSharedState.instance.lastDish;
    _revealAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _audio.playSfx(GameSfx.dishCardReveal);

    // Start fallback video
    _initFallbackVideo();

    if (_dish != null) {
      _kickOffPipeline();
    }
  }

  @override
  void dispose() {
    _revealAnim.dispose();
    _pulseAnim.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Video Management ──

  /// Play a pre-seeded cooking video while AI works.
  void _initFallbackVideo() {
    try {
      _videoController = VideoPlayerController.asset(
        'assets/videos/tonkotsu_broth_pour.mp4',
      )
        ..setLooping(true)
        ..setVolume(0.3)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _videoController!.play();
          }
        }).catchError((Object e) {
          _log.logError('DishReveal', 'fallback video', '$e');
        });
    } catch (e) {
      _log.logError('DishReveal', 'fallback video init', '$e');
    }
  }

  /// Replace fallback video with AI-generated one.
  void _switchToAiVideo(String url) {
    _videoController?.dispose();
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(0.3)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
        }
      });
  }

  // ── AI Pipeline ──

  void _kickOffPipeline() {
    final dish = _dish!;
    final photoBytes = FtueSharedState.instance.lastPhotoBytes;

    // 1. 3D model via Tripo — independent
    if (photoBytes != null) {
      _generate3DModel(photoBytes);
    } else {
      setState(() => _tripoLoading = false);
    }

    // 2. Cooking video via Seedance — independent
    _generateVideo(dish);

    // 3. Description → recipe (sequential)
    _descriptionThenRecipe(dish, photoBytes);
  }

  /// Short description → recipe.
  Future<void> _descriptionThenRecipe(Dish dish, Uint8List? photoBytes) async {
    // ── Description ──
    if (photoBytes != null) {
      try {
        final desc = await _guide.identifyDish(photoBytes);
        // Truncate to 2 sentences for snappy display
        final short = _shortenDescription(desc);
        if (mounted) {
          setState(() {
            _chefLine = short;
            _chefMood = SousChefMood.excited;
          });
          _audio.speakLine(short);
        }
      } catch (e) {
        _log.logError('DishReveal', 'description', '$e');
        if (mounted) {
          setState(() {
            _chefLine = 'What a beautiful bowl! Classic ${dish.name}.';
            _chefMood = SousChefMood.excited;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _chefLine = '${dish.name}! A magnificent choice.';
          _chefMood = SousChefMood.excited;
        });
      }
    }

    // Show dish card
    if (mounted) setState(() => _phase = 1);

    // ── Recipe ──
    try {
      _log.logInfo('DishReveal', 'Generating recipe for ${dish.name}');
      if (mounted) {
        setState(() {
          _chefLine = 'Working out the recipe...';
          _chefMood = SousChefMood.thinking;
        });
      }
      final recipe = await _guide.generateRecipe();
      if (mounted) {
        setState(() {
          _recipe = recipe;
          _recipeLoading = false;
          _chefLine = 'We did it! ${recipe.dishName} is now on your menu!';
          _chefMood = SousChefMood.excited;
        });
        _log.logSuccess('DishReveal', 'recipe', recipe.dishName);
        _checkAllDone();
      }
    } catch (e) {
      _log.logError('DishReveal', 'recipe', '$e');
      if (mounted) {
        setState(() {
          _recipeLoading = false;
          _chefLine = 'The recipe is ready! Let\'s add it to the menu.';
          _chefMood = SousChefMood.neutral;
        });
        _checkAllDone();
      }
    }
  }

  /// Truncate to first 2 sentences for snappy narration.
  String _shortenDescription(String desc) {
    final sentences = desc.split(RegExp(r'[.!?]\s+'));
    if (sentences.length <= 2) return desc;
    return '${sentences[0]}. ${sentences[1]}.';
  }

  void _generate3DModel(Uint8List photoBytes) {
    try {
      _tripo.startGeneration(photoBytes).then((taskId) {
        _log.logInfo('DishReveal', 'Tripo task: $taskId');
        _tripo.startPollingInBackground(
          taskId,
          (url) {
            if (mounted) {
              setState(() {
                _glbUrl = url;
                _tripoLoading = false;
              });
              _log.logSuccess('DishReveal', '3D model', url);
              _checkAllDone();
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() => _tripoLoading = false);
              _checkAllDone();
            }
          },
          onStatus: (_) {},
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _tripoLoading = false);
        _checkAllDone();
      }
    }
  }

  void _generateVideo(Dish dish) {
    try {
      _seedance
          .startGeneration(
        'A master Japanese chef carefully preparing ${dish.name}, '
        'plating at a clean wooden counter. '
        'Dreamy anime aesthetic, soft pastel colours, warm golden lighting, '
        'cinematic food documentary, slow movements, close-up shots.',
      )
          .then((taskId) {
        _log.logInfo('DishReveal', 'Seedance task: $taskId');
        _seedance.startPollingInBackground(
          taskId,
          (url) {
            if (mounted) {
              setState(() {
                _videoUrl = url;
                _seedanceLoading = false;
              });
              _switchToAiVideo(url);
              _log.logSuccess('DishReveal', 'video', url);
              _checkAllDone();
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() => _seedanceLoading = false);
              _checkAllDone();
            }
          },
          onStatus: (_) {},
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _seedanceLoading = false);
        _checkAllDone();
      }
    }
  }

  void _checkAllDone() {
    if (!_recipeLoading && !_tripoLoading && !_seedanceLoading) {
      setState(() => _phase = 2);
    } else if (!_recipeLoading) {
      // Recipe done is enough to show continue button
      setState(() {
        if (_phase < 1) _phase = 1;
      });
    }
  }

  /// Transition to the restaurant kitchen (NOT the map).
  void _continueToKitchen() async {
    final isFirstLaunch = await FtueService.instance.isFirstLaunch();
    if (isFirstLaunch) {
      await FtueService.instance.markComplete();
      await FtueService.instance.saveStep(FtueStep.mapTransition);
      ref.invalidate(ftueCompleteProvider);
    }

    FtueSharedState.instance.clear();

    if (mounted) {
      _audio.playSfx(GameSfx.cashDing);
      widget.game.hideOverlay(GameOverlay.dishReveal);
      // Go to shop scene (restaurant kitchen) — this is where the game loop runs.
      // ShopScene shows the kitchen background with warm lighting + HUD overlay.
      widget.game.switchScene(ShopScene(), 'shop');
      ref.read(gamePhaseProvider.notifier).set(GamePhase.shop);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final dish = _dish;
    if (dish == null) {
      return const Center(
        child: Text('No dish data', style: TextStyle(color: Colors.white)),
      );
    }

    return AnimatedBuilder(
      animation: _revealAnim,
      builder: (context, child) {
        return Opacity(opacity: _revealAnim.value, child: child);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Kitchen background ──
          Image.asset(
            'assets/sprites/kitchen_bg.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1A0A05),
                    Color(0xFF2D1508),
                    Color(0xFF1A0A05),
                  ],
                ),
              ),
            ),
          ),

          // ── Layer 2: Dark overlay ──
          Container(color: const Color.fromRGBO(0, 0, 0, 0.55)),

          // ── Layer 3: Video window (top area) ──
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            height: MediaQuery.of(context).size.height * 0.28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video content
                  if (_videoController != null &&
                      _videoController!.value.isInitialized)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFF0A0A0A),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🍜', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 8),
                            CircularProgressIndicator(
                              color: Colors.deepOrange,
                              strokeWidth: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Border
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.deepOrange.withAlpha(80),
                          width: 2,
                        ),
                      ),
                    ),
                  ),

                  // AI status badges (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _statusChip(
                          '🎬 Video',
                          _seedanceLoading,
                          _videoUrl != null,
                        ),
                        const SizedBox(height: 4),
                        _statusChip(
                          '🧊 3D',
                          _tripoLoading,
                          _glbUrl != null,
                        ),
                        const SizedBox(height: 4),
                        _statusChip(
                          '📜 Recipe',
                          _recipeLoading,
                          _recipe != null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Layer 4: Dish card (slides in at phase 1) ──
          if (_phase >= 1)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.28 + 24,
              left: 16,
              right: 16,
              child: _dishCard(dish),
            ),

          // ── Layer 5: Sous chef portrait ──
          Positioned(
            bottom: 200,
            left: 8,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Image.asset(
                'assets/${GameAssetService.sousChefPortrait(_chefMood)}',
                key: ValueKey(_chefMood),
                height: 160,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 160,
                  child: Center(
                    child: Text('🧑‍🍳', style: TextStyle(fontSize: 80)),
                  ),
                ),
              ),
            ),
          ),

          // ── Layer 6: Dialogue + action box (bottom) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xE6101020),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepOrange.withAlpha(100),
                  width: 2,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chef name
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'The Master 🍜',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dialogue text
                    Text(
                      _chefLine,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Continue button or loading
                    if (!_recipeLoading)
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _continueToKitchen,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('🍜', style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text(
                                'Add to Menu & Open Shop!',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (context, child) {
                              return Opacity(
                                opacity: 0.5 + 0.5 * _pulseAnim.value,
                                child: child,
                              );
                            },
                            child: const Text(
                              'AI is working its magic...',
                              style: TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget Helpers ──

  Widget _statusChip(String label, bool loading, bool success) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(width: 4),
          if (loading)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: Colors.deepOrange,
              ),
            )
          else if (success)
            const Icon(Icons.check_circle, color: Colors.green, size: 12)
          else
            const Icon(Icons.error_outline, color: Colors.orange, size: 12),
        ],
      ),
    );
  }

  Widget _dishCard(Dish dish) {
    final rarityColor = switch (dish.rarityTier) {
      1 => Colors.grey.shade400,
      2 => Colors.blue.shade400,
      3 => Colors.purple.shade400,
      4 => Colors.amber.shade400,
      _ => Colors.grey.shade400,
    };
    final rarityLabel = switch (dish.rarityTier) {
      1 => 'Common',
      2 => 'Regional',
      3 => 'Rare',
      4 => 'Legendary',
      _ => 'Common',
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withAlpha(50),
            Colors.black.withAlpha(180),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rarityColor.withAlpha(120), width: 2),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withAlpha(40),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Bowl sprite
          Image.asset(
            'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
            width: 80,
            height: 80,
            errorBuilder: (_, __, ___) =>
                const Text('🍜', style: TextStyle(fontSize: 50)),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.regionalStyle,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: rarityColor.withAlpha(60),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '★ $rarityLabel',
                        style: TextStyle(
                          color: rarityColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (dish.price != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '¥${dish.price}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
