import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
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
///   Phase 0: Loading — video plays + sous chef describes the dish
///   Phase 1: Dish card slides in with recipe results
///   Phase 2: 3D model reveal — interactive GLB viewer fills screen
///   Phase 3: "Added to Menu!" — tap to go to restaurant kitchen
///
/// The 3D model is the grand finale — when Tripo finishes,
/// it replaces the video window with an interactive 3D bowl.
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

  // Reveal phase: 0=loading, 1=dish card visible, 2=3D reveal, 3=all done
  int _phase = 0;

  // Whether the user has seen the 3D reveal
  bool _show3DViewer = false;

  // Animations
  late AnimationController _revealAnim;
  late AnimationController _pulseAnim;
  late AnimationController _glowAnim;

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

    _glowAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
    _glowAnim.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ── Video Management ──

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

    // 1. 3D model via Tripo
    if (photoBytes != null) {
      _generate3DModel(photoBytes);
    } else {
      setState(() => _tripoLoading = false);
    }

    // 2. Cooking video via Seedance
    _generateVideo(dish);

    // 3. Description → recipe (sequential)
    _descriptionThenRecipe(dish, photoBytes);
  }

  Future<void> _descriptionThenRecipe(Dish dish, Uint8List? photoBytes) async {
    // ── Description ──
    if (photoBytes != null) {
      try {
        final desc = await _guide.identifyDish(photoBytes);
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
          _chefLine = 'Recipe unlocked! ${recipe.dishName} is ready.';
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
          _chefLine = "The recipe is ready! Let's add it to the menu.";
          _chefMood = SousChefMood.neutral;
        });
        _checkAllDone();
      }
    }
  }

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
      // Everything ready — if 3D model exists, trigger grand reveal
      if (_glbUrl != null && !_show3DViewer) {
        _trigger3DReveal();
      } else {
        setState(() => _phase = 3);
      }
    } else if (!_recipeLoading && !_tripoLoading && _glbUrl != null) {
      // 3D ready + recipe ready — don't wait for video
      if (!_show3DViewer) {
        _trigger3DReveal();
      }
    }
  }

  void _trigger3DReveal() {
    _audio.playSfx(GameSfx.dishCardReveal);
    setState(() {
      _show3DViewer = true;
      _phase = 2;
      _chefLine = 'Behold your creation in 3D! Rotate it with your finger.';
      _chefMood = SousChefMood.excited;
    });
    _audio.speakLine(_chefLine);
    // Auto-advance to phase 3 after a moment
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _phase == 2) {
        setState(() => _phase = 3);
      }
    });
  }

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
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            color: Color.fromRGBO(0, 0, 0, _show3DViewer ? 0.75 : 0.55),
          ),

          // ── Layer 3: Main showcase area (top 45%) ──
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            height: MediaQuery.of(context).size.height * 0.40,
            child: _buildShowcaseArea(),
          ),

          // ── Layer 4: Dish card (slides in at phase 1+) ──
          if (_phase >= 1 && !_show3DViewer)
            Positioned(
              top: MediaQuery.of(context).size.height * 0.40 + 24,
              left: 16,
              right: 16,
              child: _dishCard(dish),
            ),

          // ── Layer 5: Sous chef portrait ──
          if (!_show3DViewer)
            Positioned(
              bottom: 200,
              left: 8,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Image.asset(
                  'assets/${GameAssetService.sousChefPortrait(_chefMood)}',
                  key: ValueKey(_chefMood),
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 140,
                    child: Center(
                      child: Text('🧑‍🍳', style: TextStyle(fontSize: 70)),
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
            child: _buildDialogueBox(dish),
          ),
        ],
      ),
    );
  }

  /// The main showcase: video → 3D model (transitions when GLB ready)
  Widget _buildShowcaseArea() {
    if (_show3DViewer && _glbUrl != null) {
      return _build3DViewer();
    }
    return _buildVideoWindow();
  }

  /// Interactive 3D model viewer — the grand finale
  Widget _build3DViewer() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AnimatedBuilder(
        animation: _glowAnim,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color.lerp(
                  const Color(0xFFFFD700),
                  const Color(0xFFFF6B00),
                  _glowAnim.value,
                )!,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    const Color(0x60FFD700),
                    const Color(0x60FF6B00),
                    _glowAnim.value,
                  )!,
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 3D model
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Flutter3DViewer(
                src: _glbUrl!,
              ),
            ),

            // "3D" badge
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xE0000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0x60FFD700)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🧊', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 6),
                    Text(
                      '3D MODEL',
                      style: TextStyle(
                        color: Color(0xFFFFD700),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Rotate hint
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xA0000000),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '↻ Drag to rotate',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Video window with AI status badges
  Widget _buildVideoWindow() {
    return ClipRRect(
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
    );
  }

  Widget _buildDialogueBox(Dish dish) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xE6101020),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _show3DViewer
              ? const Color(0x60FFD700)
              : Colors.deepOrange.withAlpha(100),
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
                color: _show3DViewer
                    ? const Color(0x30FFD700)
                    : Colors.deepOrange.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'The Master 🍜',
                style: TextStyle(
                  color: _show3DViewer
                      ? const Color(0xFFFFD700)
                      : Colors.deepOrange,
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
            if (_phase >= 3 || (!_recipeLoading && _show3DViewer))
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _continueToKitchen,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _show3DViewer
                        ? const Color(0xFFFFD700)
                        : Colors.deepOrange,
                    foregroundColor:
                        _show3DViewer ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🍜', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(
                        _show3DViewer
                            ? 'Add to Menu & Open Kitchen!'
                            : 'Add to Menu & Open Shop!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (!_recipeLoading)
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
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
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
                  style:
                      const TextStyle(color: Colors.white60, fontSize: 13),
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
