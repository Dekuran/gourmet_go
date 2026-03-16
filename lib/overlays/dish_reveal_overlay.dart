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
/// Scrollable landscape-friendly layout showing ALL AI outputs:
///   • Dish description (narrated via TTS)
///   • Recipe details (ingredients + steps)
///   • 4 step videos (3 prep steps + serving) from recipe seedance_prompts
///   • Interactive 3D model viewer
///
/// Everything is visible simultaneously — nothing overrides anything else.
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

  // ── Pastel anime palette ──
  static const _warmPink = Color(0xFFE8A0BF);
  static const _softGold = Color(0xFFD4A574);
  static const _mistyLavender = Color(0xFFB8A9C9);
  static const _deepWarm = Color(0xFF3D2B1F);
  static const _cardBg = Color(0xE6101020);

  // Data from camera overlay via FtueSharedState
  Dish? _dish;

  // ── AI pipeline state ──
  Recipe? _recipe;
  bool _recipeLoading = true;

  String? _glbUrl;
  bool _tripoLoading = true;

  // Description from Claude (narrated via TTS)
  String _description = '';
  bool _descriptionLoading = true;

  // 4 step videos: indices 0-2 = recipe steps, index 3 = serving
  final List<String?> _stepVideoUrls = [null, null, null, null];
  final List<bool> _stepVideoLoading = [false, false, false, false];
  final List<String> _stepLabels = ['Step 1', 'Step 2', 'Step 3', 'Serving'];
  final List<VideoPlayerController?> _stepVideoControllers = [
    null,
    null,
    null,
    null,
  ];

  // Fallback video (plays while AI generates)
  VideoPlayerController? _fallbackVideoController;

  // Animations
  late AnimationController _revealAnim;
  late AnimationController _pulseAnim;
  late AnimationController _glowAnim;

  // Scroll controller for auto-scrolling to new content
  final _scrollController = ScrollController();

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
    _fallbackVideoController?.dispose();
    for (final c in _stepVideoControllers) {
      c?.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // ── Fallback Video ──

  void _initFallbackVideo() {
    try {
      _fallbackVideoController = VideoPlayerController.asset(
        'assets/videos/tonkotsu_broth_pour.mp4',
      )
        ..setLooping(true)
        ..setVolume(0.3)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _fallbackVideoController!.play();
          }
        }).catchError((Object e) {
          _log.logError('DishReveal', 'fallback video', '$e');
        });
    } catch (e) {
      _log.logError('DishReveal', 'fallback video init', '$e');
    }
  }

  // ── AI Pipeline ──

  void _kickOffPipeline() {
    final dish = _dish!;
    final photoBytes = FtueSharedState.instance.lastPhotoBytes;

    // 1. 3D model via Tripo (starts immediately from photo)
    if (photoBytes != null) {
      _generate3DModel(photoBytes);
    } else {
      setState(() => _tripoLoading = false);
    }

    // 2. Description → recipe → step videos (sequential chain)
    _descriptionThenRecipeThenVideos(dish, photoBytes);
  }

  Future<void> _descriptionThenRecipeThenVideos(
    Dish dish,
    Uint8List? photoBytes,
  ) async {
    // ── Phase 1: Description (narrated via TTS) ──
    if (photoBytes != null) {
      try {
        final desc = await _guide.identifyDish(photoBytes);
        if (mounted) {
          setState(() {
            _description = desc;
            _descriptionLoading = false;
          });
          // Narrate the description via ElevenLabs TTS
          _audio.speakLine(desc);
          _log.logSuccess('DishReveal', 'description', '${desc.length} chars');
        }
      } catch (e) {
        _log.logError('DishReveal', 'description', '$e');
        if (mounted) {
          setState(() {
            _description = 'What a beautiful bowl! Classic ${dish.name}.';
            _descriptionLoading = false;
          });
          _audio.speakLine(_description);
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _description = '${dish.name}! A magnificent choice.';
          _descriptionLoading = false;
        });
        _audio.speakLine(_description);
      }
    }

    // ── Phase 2: Recipe generation ──
    try {
      _log.logInfo('DishReveal', 'Generating recipe for ${dish.name}');
      final recipe = await _guide.generateRecipe();
      if (mounted) {
        setState(() {
          _recipe = recipe;
          _recipeLoading = false;
          // Update step labels from recipe
          for (int i = 0; i < recipe.steps.length && i < 3; i++) {
            _stepLabels[i] = recipe.steps[i].name;
          }
          _stepLabels[3] = 'Serving';
        });
        _log.logSuccess('DishReveal', 'recipe', recipe.dishName);

        // ── Phase 3: Generate 4 step videos from recipe ──
        _generateStepVideos(recipe);

        // Scroll to show recipe
        _autoScroll();
      }
    } catch (e) {
      _log.logError('DishReveal', 'recipe', '$e');
      if (mounted) {
        setState(() => _recipeLoading = false);
      }
    }
  }

  /// Generate 4 Seedance videos: 3 from recipe steps + 1 serving.
  void _generateStepVideos(Recipe recipe) {
    // Collect all 4 prompts
    final prompts = <String>[];
    for (final step in recipe.steps.take(3)) {
      prompts.add(step.seedancePrompt);
    }
    // Pad with generic prompts if fewer than 3 steps
    while (prompts.length < 3) {
      prompts.add(
        'Japanese chef cooking ${recipe.dishName}, cinematic food documentary, '
        'warm lighting, close-up shots',
      );
    }
    // 4th video: serving prompt
    prompts.add(
      recipe.servingVideoPrompt.isNotEmpty
          ? recipe.servingVideoPrompt
          : 'A steaming bowl of ${recipe.dishName} being served on a wooden counter, '
              'cinematic food documentary style, warm ambient lighting',
    );

    // Launch all 4 generations in parallel
    for (int i = 0; i < 4; i++) {
      _generateSingleVideo(i, prompts[i]);
    }
  }

  void _generateSingleVideo(int index, String prompt) {
    setState(() => _stepVideoLoading[index] = true);
    _log.logInfo('DishReveal', 'Seedance[$index] starting: ${prompt.substring(0, prompt.length.clamp(0, 60))}...');

    try {
      _seedance.startGeneration(prompt).then((taskId) {
        _log.logInfo('DishReveal', 'Seedance[$index] task: $taskId');
        _seedance.startPollingInBackground(
          taskId,
          (url) {
            if (mounted) {
              setState(() {
                _stepVideoUrls[index] = url;
                _stepVideoLoading[index] = false;
              });
              _initStepVideoController(index, url);
              _log.logSuccess('DishReveal', 'Seedance[$index]', url);
            }
          },
          onError: (err) {
            _log.logError('DishReveal', 'Seedance[$index] error', err);
            if (mounted) {
              setState(() => _stepVideoLoading[index] = false);
            }
          },
          onStatus: (status) {
            _log.logInfo('DishReveal', 'Seedance[$index]: $status');
          },
        );
      }).catchError((Object e) {
        _log.logError('DishReveal', 'Seedance[$index] start', '$e');
        if (mounted) {
          setState(() => _stepVideoLoading[index] = false);
        }
      });
    } catch (e) {
      _log.logError('DishReveal', 'Seedance[$index]', '$e');
      if (mounted) {
        setState(() => _stepVideoLoading[index] = false);
      }
    }
  }

  void _initStepVideoController(int index, String url) {
    _stepVideoControllers[index]?.dispose();
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _stepVideoControllers[index] = ctrl;
    ctrl.setLooping(true);
    ctrl.setVolume(0.0); // muted by default
    ctrl.initialize().then((_) {
      if (mounted) {
        setState(() {});
        ctrl.play();
      }
    }).catchError((Object e) {
      _log.logError('DishReveal', 'video[$index] init', '$e');
    });
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
              _audio.playSfx(GameSfx.dishCardReveal);
              _autoScroll();
            }
          },
          onError: (err) {
            if (mounted) setState(() => _tripoLoading = false);
          },
          onStatus: (_) {},
        );
      });
    } catch (e) {
      if (mounted) setState(() => _tripoLoading = false);
    }
  }

  void _autoScroll() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  bool get _canContinue => !_recipeLoading;

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

    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700; // landscape / desktop

    return AnimatedBuilder(
      animation: _revealAnim,
      builder: (context, child) {
        return Opacity(opacity: _revealAnim.value, child: child);
      },
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A0A05),
              Color(0xFF0A0515),
              Color(0xFF1A0A05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Fixed Header: Dish identity ──
              _buildHeader(dish),

              // ── Scrollable content ──
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Description (narrated)
                      _buildDescriptionSection(),
                      const SizedBox(height: 16),

                      // 2. AI Pipeline Status
                      _buildPipelineStatus(),
                      const SizedBox(height: 16),

                      // 3. Recipe (ingredients + steps)
                      if (_recipe != null) ...[
                        _buildRecipeSection(_recipe!),
                        const SizedBox(height: 20),
                      ],

                      // 4. Step Videos (4 in order)
                      _buildVideoGallery(isWide),
                      const SizedBox(height: 20),

                      // 5. 3D Model
                      _build3DSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ── Fixed Footer: Action button ──
              _buildFooter(dish),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(Dish dish) {
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          bottom: BorderSide(color: rarityColor.withAlpha(80), width: 2),
        ),
      ),
      child: Row(
        children: [
          // Bowl sprite
          Image.asset(
            'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) =>
                const Text('🍜', style: TextStyle(fontSize: 32)),
          ),
          const SizedBox(width: 12),
          // Name + style
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
                Text(
                  dish.regionalStyle,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
          ),
          // Rarity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: rarityColor.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rarityColor.withAlpha(100)),
            ),
            child: Text(
              '★ $rarityLabel',
              style: TextStyle(
                color: rarityColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          if (dish.price != null) ...[
            const SizedBox(width: 8),
            Text(
              '¥${dish.price}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Description Section ──

  Widget _buildDescriptionSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warmPink.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warmPink.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sous chef portrait
          Image.asset(
            'assets/${GameAssetService.sousChefExcited}',
            height: 80,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                const Text('🧑‍🍳', style: TextStyle(fontSize: 48)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // "The Master" label
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _warmPink.withAlpha(40),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🍜', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'The Master',
                        style: TextStyle(
                          color: _warmPink,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text('🔊',
                          style: TextStyle(fontSize: 10)), // TTS indicator
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Description text
                if (_descriptionLoading)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _warmPink,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Opacity(
                          opacity: 0.5 + 0.5 * _pulseAnim.value,
                          child: child,
                        ),
                        child: const Text(
                          'Examining the dish...',
                          style: TextStyle(
                            color: _warmPink,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pipeline Status Badges ──

  Widget _buildPipelineStatus() {
    final anyVideoLoading = _stepVideoLoading.any((v) => v);
    final anyVideoDone = _stepVideoUrls.any((v) => v != null);
    final videosComplete =
        _stepVideoUrls.where((v) => v != null).length;
    final videosTotal = _stepVideoUrls.length;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _statusChip('📝 Description', _descriptionLoading,
            _description.isNotEmpty && !_descriptionLoading),
        _statusChip(
            '📜 Recipe', _recipeLoading, _recipe != null),
        _statusChip(
          '🎬 Videos ($videosComplete/$videosTotal)',
          anyVideoLoading,
          videosComplete == videosTotal && anyVideoDone,
        ),
        _statusChip('🧊 3D Model', _tripoLoading, _glbUrl != null),
      ],
    );
  }

  Widget _statusChip(String label, bool loading, bool success) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: success
              ? Colors.green.withAlpha(80)
              : loading
                  ? _softGold.withAlpha(60)
                  : Colors.white.withAlpha(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 6),
          if (loading)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: _softGold,
              ),
            )
          else if (success)
            const Icon(Icons.check_circle, color: Colors.green, size: 14)
          else
            const Icon(Icons.circle_outlined, color: Colors.white24, size: 14),
        ],
      ),
    );
  }

  // ── Recipe Section ──

  Widget _buildRecipeSection(Recipe recipe) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _softGold.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _softGold.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              const Text('📜', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                recipe.dishName,
                style: const TextStyle(
                  color: _softGold,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _softGold.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${recipe.region} · ${recipe.prefecture}',
                  style: const TextStyle(
                    color: _softGold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Teaser
          if (recipe.teaser.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '"${recipe.teaser}"',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),

          // Ingredients
          const Text(
            'Ingredients',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: recipe.ingredients.map((ing) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _softGold.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${ing.name} (${ing.amount})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Steps
          const Text(
            'Preparation Steps',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          ...recipe.steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _softGold.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: _softGold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          step.description,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Video Gallery ──

  Widget _buildVideoGallery(bool isWide) {
    // Only show section header if any videos have started
    final anyStarted =
        _stepVideoLoading.any((v) => v) || _stepVideoUrls.any((v) => v != null);

    if (!anyStarted && _recipeLoading) {
      // Recipe not yet loaded, show fallback video
      return _buildFallbackVideoSection();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          children: [
            const Text('🎬', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text(
              'Cooking Videos',
              style: TextStyle(
                color: _mistyLavender,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_stepVideoUrls.where((v) => v != null).length}/4 generated',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Video grid: 2x2 on wide screens, vertical on narrow
        if (isWide)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(4, (i) => _buildVideoTile(i, isWide)),
          )
        else
          Column(
            children: List.generate(
              4,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildVideoTile(i, isWide),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🎬', style: TextStyle(fontSize: 18)),
            SizedBox(width: 8),
            Text(
              'Cooking Preview',
              style: TextStyle(
                color: _mistyLavender,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _fallbackVideoController != null &&
                    _fallbackVideoController!.value.isInitialized
                ? VideoPlayer(_fallbackVideoController!)
                : Container(
                    color: const Color(0xFF0A0A0A),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🍜', style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          CircularProgressIndicator(
                            color: _mistyLavender,
                            strokeWidth: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoTile(int index, bool isWide) {
    final url = _stepVideoUrls[index];
    final loading = _stepVideoLoading[index];
    final controller = _stepVideoControllers[index];
    final label = _stepLabels[index];
    final isServing = index == 3;

    final tileWidth = isWide
        ? (MediaQuery.of(context).size.width - 64 - 12) / 2
        : double.infinity;

    return SizedBox(
      width: isWide ? tileWidth : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step label
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isServing
                      ? _warmPink.withAlpha(30)
                      : _mistyLavender.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isServing ? '🍜 $label' : '${index + 1}. $label',
                  style: TextStyle(
                    color: isServing ? _warmPink : _mistyLavender,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              if (loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _mistyLavender,
                  ),
                )
              else if (url != null)
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
            ],
          ),
          const SizedBox(height: 6),
          // Video area
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: url != null
                        ? Colors.green.withAlpha(60)
                        : loading
                            ? _mistyLavender.withAlpha(40)
                            : Colors.white.withAlpha(15),
                    width: 1.5,
                  ),
                ),
                child: controller != null && controller.value.isInitialized
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(controller),
                          // Play/replay overlay
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white54,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : loading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseAnim,
                                  builder: (context, child) => Opacity(
                                    opacity: 0.4 + 0.6 * _pulseAnim.value,
                                    child: child,
                                  ),
                                  child: Text(
                                    isServing ? '🍜' : '🔥',
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Generating...',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : url == null && !loading
                            ? const Center(
                                child: Text(
                                  'Waiting for recipe...',
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 11,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 3D Model Section ──

  Widget _build3DSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          children: [
            const Text('🧊', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Text(
              '3D Model',
              style: TextStyle(
                color: Color(0xFFFFD700),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_tripoLoading)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFFFD700),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Generating...',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              )
            else if (_glbUrl != null)
              const Text(
                '↻ Drag to rotate',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // 3D viewer or placeholder
        AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            final hasModel = _glbUrl != null;
            return Container(
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasModel
                      ? Color.lerp(
                          const Color(0xFFFFD700),
                          const Color(0xFFFF6B00),
                          _glowAnim.value,
                        )!
                      : Colors.white.withAlpha(15),
                  width: hasModel ? 2.5 : 1.5,
                ),
                boxShadow: hasModel
                    ? [
                        BoxShadow(
                          color: Color.lerp(
                            const Color(0x40FFD700),
                            const Color(0x40FF6B00),
                            _glowAnim.value,
                          )!,
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: child,
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: _glbUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Flutter3DViewer(src: _glbUrl!),
                      // 3D badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xD0000000),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0x50FFD700),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🧊', style: TextStyle(fontSize: 14)),
                              SizedBox(width: 4),
                              Text(
                                '3D MODEL',
                                style: TextStyle(
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _tripoLoading
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedBuilder(
                              animation: _pulseAnim,
                              builder: (context, child) => Opacity(
                                opacity: 0.4 + 0.6 * _pulseAnim.value,
                                child: child,
                              ),
                              child: const Text(
                                '🧊',
                                style: TextStyle(fontSize: 40),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Creating 3D model from your photo...',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'This may take 1-2 minutes',
                              style: TextStyle(
                                color: Colors.white24,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      )
                    : const Center(
                        child: Text(
                          '3D model unavailable',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 13,
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  // ── Footer ──

  Widget _buildFooter(Dish dish) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border(
          top: BorderSide(color: _warmPink.withAlpha(40), width: 1),
        ),
      ),
      child: _canContinue
          ? SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _continueToKitchen,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _warmPink,
                  foregroundColor: _deepWarm,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🍜', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text(
                      'Add to Menu & Open Kitchen!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _warmPink,
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (context, child) => Opacity(
                    opacity: 0.5 + 0.5 * _pulseAnim.value,
                    child: child,
                  ),
                  child: const Text(
                    'AI is working its magic...',
                    style: TextStyle(color: _warmPink, fontSize: 14),
                  ),
                ),
              ],
            ),
    );
  }
}
