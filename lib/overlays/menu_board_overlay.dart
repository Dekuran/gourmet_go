import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../models/dish.dart';
import '../providers/game_providers.dart';
import '../services/game_asset_service.dart';

/// Menu board overlay — styled as a Japanese storefront food display case.
///
/// Resembles the glass display cases (食品サンプル / shokuhin sampuru)
/// found outside Japanese restaurants, showing plastic food replicas.
/// Each dish sits in a subtle bordered cell. Tapping a dish opens
/// a detail panel with the recipe, description, and stats.
class MenuBoardOverlay extends ConsumerStatefulWidget {
  const MenuBoardOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  ConsumerState<MenuBoardOverlay> createState() => _MenuBoardOverlayState();
}

class _MenuBoardOverlayState extends ConsumerState<MenuBoardOverlay> {
  Dish? _selectedDish;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop
          GestureDetector(
            onTap: () => widget.game.hideOverlay(GameOverlay.menuBoard),
            child: Container(color: Colors.black.withAlpha(180)),
          ),
          // Main display case
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 560),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // Warm wood-grain background for the display case
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5C3D2E), // dark wood
                    Color(0xFF8B5E3C), // warm wood
                    Color(0xFF5C3D2E),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4A574),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(150),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  children: [
                    // ── Header bar (wooden sign) ──
                    _buildHeader(),
                    // ── Content ──
                    Expanded(
                      child: _selectedDish != null
                          ? _buildDetailView(_selectedDish!)
                          : _buildDisplayCase(menu),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3D2B1F), Color(0xFF5C3D2E)],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD4A574), width: 2),
        ),
      ),
      child: Row(
        children: [
          const Text('🏮', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDish != null ? _selectedDish!.name : 'お品書き — Menu',
                  style: const TextStyle(
                    color: Color(0xFFF5DEB3),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _selectedDish != null
                      ? 'Tap ← to return to display'
                      : 'Tap a dish to inspect',
                  style: TextStyle(
                    color: const Color(0xFFF5DEB3).withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedDish != null)
            IconButton(
              onPressed: () => setState(() => _selectedDish = null),
              icon: const Icon(Icons.arrow_back, color: Color(0xFFF5DEB3)),
              tooltip: 'Back to menu',
            ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () =>
                widget.game.hideOverlay(GameOverlay.menuBoard),
            icon: const Icon(Icons.close, color: Color(0xFFF5DEB3)),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  /// The main grid of food samples in display cases.
  Widget _buildDisplayCase(List<Dish> menu) {
    if (menu.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🍜', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'Display case is empty.',
              style: TextStyle(color: Color(0xFFF5DEB3), fontSize: 16),
            ),
            SizedBox(height: 4),
            Text(
              'Photograph ramen to add dishes!',
              style: TextStyle(color: Color(0xAAF5DEB3), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.85,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: menu.length,
        itemBuilder: (context, index) =>
            _FoodSampleCell(
              dish: menu[index],
              onTap: () => setState(() => _selectedDish = menu[index]),
            ),
      ),
    );
  }

  /// Detail view for a selected dish — recipe, lore, stats.
  Widget _buildDetailView(Dish dish) {
    final rarityColor = _rarityColor(dish.rarityTier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Large food sample display
          SizedBox(
            width: 220,
            child: Column(
              children: [
                // Bowl display — 3D model if available, sprite fallback
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: rarityColor.withAlpha(120), width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: dish.glbUrl != null
                      ? Stack(
                          children: [
                            Positioned.fill(
                              child: Flutter3DViewer(src: dish.glbUrl!),
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(160),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '↻ Drag to spin',
                                  style: TextStyle(
                                    color: Color(0xAAF5DEB3),
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Image.asset(
                            'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
                            width: 140,
                            height: 140,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Text('🍜', style: TextStyle(fontSize: 72)),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                // Price tag
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(100),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.amber.withAlpha(80)),
                  ),
                  child: Text(
                    '${dish.effectivePrice}c',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Rarity badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: rarityColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: rarityColor.withAlpha(80)),
                  ),
                  child: Text(
                    '★ ${dish.rarityLabel.toUpperCase()}',
                    style: TextStyle(
                      color: rarityColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // Right: Info panels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Region & broth
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(icon: '🗾', label: dish.regionalStyle),
                    _InfoChip(icon: '🍲', label: dish.brothBase.toUpperCase()),
                    if (dish.confidence != null)
                      _InfoChip(
                        icon: '🎯',
                        label:
                            '${(dish.confidence! * 100).toStringAsFixed(0)}% match',
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Story / Lore
                _DetailSection(
                  icon: '📜',
                  title: 'Dish Story',
                  child: Text(
                    dish.recipeSummary ??
                        dish.regionalLore ??
                        'A classic bowl waiting to be discovered.',
                    style: const TextStyle(
                      color: Color(0xCCF5DEB3),
                      fontSize: 14,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Ingredients
                _DetailSection(
                  icon: '🥢',
                  title: 'Ingredients',
                  child: dish.recipeIngredients.isEmpty
                      ? const Text(
                          'Recipe details will appear after generation.',
                          style: TextStyle(color: Color(0x88F5DEB3)),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: dish.recipeIngredients
                              .map((ing) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(10),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withAlpha(30),
                                      ),
                                    ),
                                    child: Text(
                                      ing,
                                      style: const TextStyle(
                                        color: Color(0xCCF5DEB3),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _rarityColor(int tier) => switch (tier) {
        1 => Colors.grey.shade400,
        2 => Colors.blue.shade400,
        3 => Colors.purple.shade400,
        4 => Colors.amber.shade400,
        _ => Colors.grey.shade400,
      };
}

/// A single food sample cell in the display grid.
///
/// Resembles a glass-topped display compartment with the plastic
/// food replica (bowl sprite) and a small name tag below.
class _FoodSampleCell extends StatelessWidget {
  const _FoodSampleCell({required this.dish, required this.onTap});

  final Dish dish;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rarityColor = switch (dish.rarityTier) {
      1 => Colors.grey.shade400,
      2 => Colors.blue.shade400,
      3 => Colors.purple.shade400,
      4 => Colors.amber.shade400,
      _ => Colors.grey.shade400,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          // Glass display case effect
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(40),
              Colors.black.withAlpha(100),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: rarityColor.withAlpha(60),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withAlpha(20),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Bowl sprite (the "plastic food replica")
            Image.asset(
              'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Text('🍜', style: TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 8),
            // Name tag
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5DEB3).withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dish.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFF5DEB3),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Price + rarity indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dish.effectivePrice}c',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: rarityColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCF5DEB3),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final String icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD4A574).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFF5DEB3),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
