import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../game/gourmet_go_game.dart';
import '../models/dish.dart';
import '../providers/game_providers.dart';
import '../services/game_asset_service.dart';

class MenuBoardOverlay extends ConsumerStatefulWidget {
  const MenuBoardOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  ConsumerState<MenuBoardOverlay> createState() => _MenuBoardOverlayState();
}

class _MenuBoardOverlayState extends ConsumerState<MenuBoardOverlay> {
  Dish? _selectedDish;
  VideoPlayerController? _videoController;
  int _selectedVideoIndex = 0;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    final selectedDish = _resolveSelectedDish(menu);

    return Material(
      color: Colors.black.withAlpha(210),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📋 Ramen Menu Board',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Inspect uploaded bowls, recipe clips, and 3D plating.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.game.hideOverlay(GameOverlay.menuBoard),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: menu.isEmpty
                    ? const Center(
                        child: Text(
                          'No uploaded ramen yet.',
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 900;
                          return wide
                              ? Row(
                                  children: [
                                    SizedBox(
                                      width: 300,
                                      child: _buildDishList(menu, selectedDish),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildInspector(selectedDish)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    SizedBox(
                                      height: 220,
                                      child: _buildDishList(menu, selectedDish),
                                    ),
                                    const SizedBox(height: 16),
                                    Expanded(child: _buildInspector(selectedDish)),
                                  ],
                                );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Dish _resolveSelectedDish(List<Dish> menu) {
    final selected = _selectedDish;
    if (selected != null) {
      final match = menu.where((dish) => dish.varietyId == selected.varietyId);
      if (match.isNotEmpty) return match.first;
    }
    _selectedDish = menu.first;
    _syncVideoForDish(menu.first);
    return menu.first;
  }

  Widget _buildDishList(List<Dish> menu, Dish selectedDish) {
    return ListView.separated(
      itemCount: menu.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final dish = menu[index];
        final isSelected = dish.varietyId == selectedDish.varietyId;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedDish = dish;
              _selectedVideoIndex = 0;
            });
            _syncVideoForDish(dish);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0x33E8A0BF)
                  : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE8A0BF)
                    : Colors.white.withAlpha(24),
              ),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
                  width: 52,
                  height: 52,
                  errorBuilder: (context, error, stackTrace) =>
                      const Text('🍜', style: TextStyle(fontSize: 32)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dish.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dish.regionalStyle,
                        style:
                            const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInspector(Dish dish) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dish.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Region', dish.regionalStyle),
              _chip('Broth', dish.brothBase),
              _chip('Price', dish.price == null ? 'TBD' : '${dish.price}c'),
              _chip('Videos', '${dish.recipeVideoUrls.length}'),
            ],
          ),
          const SizedBox(height: 18),
          _sectionCard(
            title: 'Dish Story',
            child: Text(
              dish.recipeSummary ?? dish.regionalLore ?? 'No tasting notes yet.',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Ingredients',
            child: dish.recipeIngredients.isEmpty
                ? const Text(
                    'Recipe ingredients will appear after generation completes.',
                    style: TextStyle(color: Colors.white54),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: dish.recipeIngredients
                        .map((ingredient) => _chip('•', ingredient))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: 'Recipe Videos',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _videoController != null &&
                            _videoController!.value.isInitialized
                        ? VideoPlayer(_videoController!)
                        : Center(
                            child: Text(
                              dish.recipeVideoUrls.isEmpty
                                  ? 'No recipe clips generated yet.'
                                  : 'Loading clip...',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                if (dish.recipeVideoUrls.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(dish.recipeVideoUrls.length, (index) {
                      final selected = index == _selectedVideoIndex;
                      final label = index < dish.recipeStepLabels.length
                          ? dish.recipeStepLabels[index]
                          : 'Clip ${index + 1}';
                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _selectedVideoIndex = index);
                          _syncVideo(dish.recipeVideoUrls[index]);
                        },
                      );
                    }),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _sectionCard(
            title: '3D Bowl Viewer',
            child: SizedBox(
              height: 280,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                ),
                clipBehavior: Clip.antiAlias,
                child: dish.glbUrl == null
                    ? const Center(
                        child: Text(
                          '3D model still cooking...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : Stack(
                        children: [
                          Positioned.fill(child: Flutter3DViewer(src: dish.glbUrl!)),
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(160),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Drag to spin',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
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

  Future<void> _syncVideoForDish(Dish dish) async {
    if (dish.recipeVideoUrls.isEmpty) {
      await _disposeVideo();
      return;
    }
    final safeIndex = _selectedVideoIndex.clamp(0, dish.recipeVideoUrls.length - 1);
    _selectedVideoIndex = safeIndex;
    await _syncVideo(dish.recipeVideoUrls[safeIndex]);
  }

  Future<void> _syncVideo(String url) async {
    await _disposeVideo();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    await controller.setLooping(true);
    await controller.play();
    if (mounted) {
      setState(() => _videoController = controller);
    } else {
      controller.dispose();
    }
  }

  Future<void> _disposeVideo() async {
    final controller = _videoController;
    _videoController = null;
    await controller?.dispose();
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    );
  }
}
