import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../game/gourmet_go_game.dart';
import '../game/scenes/map_scene.dart';
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
/// After camera identification, this overlay orchestrates:
/// 1. Animated dish card with name, region, rarity
/// 2. GuideService description (identifyDish — theatrical prose + TTS)
/// 3. GuideService recipe generation (uses conversation context from #2)
/// 4. TripoService 3D model generation (background polling)
/// 5. SeedanceService cooking video generation (background polling)
///
/// Description → recipe runs sequentially (recipe needs conversation context).
/// Tripo + Seedance fire independently in parallel.
class DishRevealOverlay extends ConsumerStatefulWidget {
  const DishRevealOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  ConsumerState<DishRevealOverlay> createState() => _DishRevealOverlayState();
}

class _DishRevealOverlayState extends ConsumerState<DishRevealOverlay>
    with SingleTickerProviderStateMixin {
  static final _log = DebugLogger.instance;
  static final _audio = GameAudioService();
  static final _guide = GuideService();
  static final _tripo = TripoService();
  static final _seedance = SeedanceService();

  // Data from camera overlay via FtueSharedState
  Dish? _dish;

  // AI pipeline state
  Recipe? _recipe;
  String? _recipeError;
  bool _recipeLoading = true;

  String? _glbUrl;
  String? _tripoStatus;
  bool _tripoLoading = true;

  String? _videoUrl;
  String? _seedanceStatus;
  bool _seedanceLoading = true;
  VideoPlayerController? _videoController;

  // Description from sous chef
  String? _description;
  bool _descriptionLoading = true;

  late AnimationController _revealAnim;

  @override
  void initState() {
    super.initState();
    _dish = FtueSharedState.instance.lastDish;
    _revealAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _audio.playSfx(GameSfx.dishCardReveal);

    if (_dish != null) {
      _kickOffPipeline();
    }
  }

  @override
  void dispose() {
    _revealAnim.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Fire AI calls — Tripo + Seedance in parallel, description → recipe sequentially.
  void _kickOffPipeline() {
    final dish = _dish!;
    final photoBytes = FtueSharedState.instance.lastPhotoBytes;

    // 1. 3D model via Tripo (needs photo bytes) — independent
    if (photoBytes != null) {
      _generate3DModel(photoBytes);
    } else {
      setState(() {
        _tripoLoading = false;
        _tripoStatus = 'No photo available';
      });
    }

    // 2. Cooking video via Seedance — independent
    _generateVideo(dish);

    // 3. Description → recipe (sequential: recipe uses conversation context)
    _descriptionThenRecipe(dish, photoBytes);
  }

  /// Sequentially: identifyDish (establishes conversation) → generateRecipe.
  ///
  /// [GuideService.generateRecipe] appends to the conversation started by
  /// [GuideService.identifyDish], so the two calls must NOT be parallelised.
  Future<void> _descriptionThenRecipe(Dish dish, Uint8List? photoBytes) async {
    // ── Description (establishes conversation context) ──
    if (photoBytes != null) {
      try {
        final desc = await _guide.identifyDish(photoBytes);
        if (mounted) {
          setState(() {
            _description = desc;
            _descriptionLoading = false;
          });
          _audio.speakLine(desc);
        }
      } catch (e) {
        _log.logError('DishReveal', 'description', '$e');
        if (mounted) setState(() => _descriptionLoading = false);
      }
    } else {
      if (mounted) setState(() => _descriptionLoading = false);
    }

    // ── Recipe (requires conversation context from identifyDish) ──
    try {
      _log.logInfo('DishReveal', 'Generating recipe for ${dish.name}');
      final recipe = await _guide.generateRecipe();
      if (mounted) {
        setState(() {
          _recipe = recipe;
          _recipeLoading = false;
        });
        _log.logSuccess('DishReveal', 'recipe', recipe.dishName);
      }
    } catch (e) {
      _log.logError('DishReveal', 'recipe', '$e');
      if (mounted) {
        setState(() {
          _recipeLoading = false;
          _recipeError = '$e';
        });
      }
    }
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
                _tripoStatus = 'Complete!';
              });
              _log.logSuccess('DishReveal', '3D model', url);
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _tripoLoading = false;
                _tripoStatus = 'Failed: $err';
              });
            }
          },
          onStatus: (status) {
            if (mounted) setState(() => _tripoStatus = status);
          },
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _tripoLoading = false;
          _tripoStatus = 'Error: $e';
        });
      }
    }
  }

  void _generateVideo(Dish dish) {
    final ingredients =
        _recipe?.ingredients.map((i) => i.name).toList() ??
        ['noodles', 'broth', 'chashu'];

    try {
      _seedance.startGeneration(
        'A master Japanese chef carefully preparing ${dish.name}, '
        'working with ${ingredients.take(3).join(", ")}, plating at a clean wooden counter. '
        'Dreamy anime-inspired aesthetic, soft pastel colours, warm golden lighting, '
        'cinematic food documentary, slow deliberate movements, close-up detail shots.',
      ).then((taskId) {
        _log.logInfo('DishReveal', 'Seedance task: $taskId');
        _seedance.startPollingInBackground(
          taskId,
          (url) {
            if (mounted) {
              setState(() {
                _videoUrl = url;
                _seedanceLoading = false;
                _seedanceStatus = 'Complete!';
              });
              _initVideoPlayer(url);
              _log.logSuccess('DishReveal', 'video', url);
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _seedanceLoading = false;
                _seedanceStatus = 'Failed: $err';
              });
            }
          },
          onStatus: (status) {
            if (mounted) setState(() => _seedanceStatus = status);
          },
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _seedanceLoading = false;
          _seedanceStatus = 'Error: $e';
        });
      }
    }
  }

  void _initVideoPlayer(String url) {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
        }
      });
  }

  void _continueToMap() async {
    // Mark FTUE complete if applicable
    final isFirstLaunch = await FtueService.instance.isFirstLaunch();
    if (isFirstLaunch) {
      await FtueService.instance.markComplete();
      await FtueService.instance.saveStep(FtueStep.mapTransition);
      ref.invalidate(ftueCompleteProvider);
    }

    // Clear shared state
    FtueSharedState.instance.clear();

    if (mounted) {
      _audio.playSfx(GameSfx.mapPulse);
      widget.game.hideOverlay(GameOverlay.dishReveal);
      widget.game.switchScene(MapScene(), 'map');
      ref.read(gamePhaseProvider.notifier).set(GamePhase.map);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dish = _dish;
    if (dish == null) {
      return const Center(child: Text('No dish data', style: TextStyle(color: Colors.white)));
    }

    return AnimatedBuilder(
      animation: _revealAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _revealAnim.value,
          child: child,
        );
      },
      child: Container(
        color: Colors.black.withAlpha(230),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header: Dish Card ──
                _buildDishCard(dish),
                const SizedBox(height: 16),

                // ── Sous Chef Description ──
                _buildSection(
                  '🍜 The Master Says',
                  _descriptionLoading,
                  _description ?? 'Analysing this beautiful bowl...',
                ),
                const SizedBox(height: 16),

                // ── Recipe ──
                _buildRecipeSection(),
                const SizedBox(height: 16),

                // ── 3D Model Status ──
                _buildAiSection(
                  '🧊 3D Model (Tripo)',
                  _tripoLoading,
                  _tripoStatus ?? 'Starting...',
                  _glbUrl != null ? '✅ Ready' : null,
                ),
                const SizedBox(height: 16),

                // ── Cooking Video ──
                _buildVideoSection(),
                const SizedBox(height: 24),

                // ── Continue Button ──
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _continueToMap,
                    icon: const Icon(Icons.map),
                    label: const Text(
                      'Explore Japan! 🗾',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDishCard(Dish dish) {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withAlpha(60),
            Colors.black.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rarityColor.withAlpha(150), width: 2),
      ),
      child: Column(
        children: [
          // Bowl sprite
          Image.asset(
            'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
            width: 100,
            height: 100,
            errorBuilder: (_, __, ___) => const Text('🍜', style: TextStyle(fontSize: 60)),
          ),
          const SizedBox(height: 12),

          // Dish name
          Text(
            dish.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // Regional style
          Text(
            dish.regionalStyle,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
          const SizedBox(height: 8),

          // Rarity badge + price
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: rarityColor.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '★ $rarityLabel',
                  style: TextStyle(color: rarityColor, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (dish.price != null) ...[
                const SizedBox(width: 12),
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

          if (dish.confidence != null) ...[
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(dish.confidence! * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool loading, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.deepOrange, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (loading)
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange)),
              const SizedBox(width: 8),
              Expanded(child: Text(content, style: const TextStyle(color: Colors.white60, fontSize: 14))),
            ])
          else
            Text(content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildRecipeSection() {
    if (_recipeLoading) {
      return _buildAiSection('📜 Recipe', true, 'Generating recipe...', null);
    }
    if (_recipeError != null) {
      return _buildAiSection('📜 Recipe', false, 'Error: $_recipeError', null);
    }
    if (_recipe == null) {
      return _buildAiSection('📜 Recipe', false, 'No recipe generated', null);
    }

    final r = _recipe!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📜 ${r.dishName}', style: const TextStyle(color: Colors.deepOrange, fontSize: 16, fontWeight: FontWeight.bold)),
          if (r.teaser.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.teaser, style: const TextStyle(color: Colors.amber, fontSize: 13, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 8),
          Text('Region: ${r.region} • ${r.prefecture}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          Text('Rarity: ${r.rarity}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          if (r.flavorTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: r.flavorTags.map((t) => Chip(
                label: Text(t, style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.deepOrange.withAlpha(80),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
          ],
          const Divider(color: Colors.white24, height: 20),

          // Ingredients
          const Text('Ingredients', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...r.ingredients.map((i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• ${i.name} — ${i.amount}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          )),
          const Divider(color: Colors.white24, height: 20),

          // Steps
          const Text('Steps', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ...r.steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.withAlpha(80),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.value.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(e.value.description, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                )),
              ],
            ),
          )),

          if (r.longDescription.isNotEmpty) ...[
            const Divider(color: Colors.white24, height: 20),
            Text(r.longDescription, style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _buildAiSection(String title, bool loading, String status, String? success) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        children: [
          if (loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange))
          else if (success != null)
            const Icon(Icons.check_circle, color: Colors.green, size: 20)
          else
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.deepOrange, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(success ?? status, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildVideoSection() {
    if (_seedanceLoading) {
      return _buildAiSection('🎬 Cooking Video (Seedance)', true, _seedanceStatus ?? 'Starting...', null);
    }
    if (_videoUrl == null) {
      return _buildAiSection('🎬 Cooking Video (Seedance)', false, _seedanceStatus ?? 'No video', null);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎬 Cooking Video', style: TextStyle(color: Colors.deepOrange, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_videoController != null && _videoController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
          const SizedBox(height: 8),
          const Text('✅ Video ready', style: TextStyle(color: Colors.green, fontSize: 12)),
        ],
      ),
    );
  }
}
