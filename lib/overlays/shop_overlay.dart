import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../models/dish.dart';
import '../providers/game_providers.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';

/// Shop / kitchen overlay — shown after FTUE completes.
///
/// Displays the player's ramen menu (discovered dishes), cash, and
/// lets them start a service day or open the map to travel.
/// This is the "home base" between the FTUE and the game loop.
class ShopOverlay extends ConsumerWidget {
  const ShopOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider);
    final cash = ref.watch(cashProvider);
    final day = ref.watch(dayProvider);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE01A0A05),
            Color(0xE82D1508),
            Color(0xF01A0A05),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    '🍜 Your Kitchen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _StatChip(icon: '💰', value: '¥$cash'),
                  const SizedBox(width: 8),
                  _StatChip(icon: '📅', value: 'Day $day'),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Sous chef welcome ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.deepOrange.withAlpha(50),
                ),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/${GameAssetService.sousChefExcited}',
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Text('🧑‍🍳', style: TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      menu.isEmpty
                          ? 'Welcome to the kitchen! Add your first ramen to get started.'
                          : menu.length == 1
                              ? 'Great start! ${menu.first.name} is on the menu. Ready to serve?'
                              : '${menu.length} dishes on the menu. Your customers await!',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Menu label ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    '📋 Your Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${menu.length} dish${menu.length == 1 ? '' : 'es'}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Menu items ──
            Expanded(
              child: menu.isEmpty
                  ? _buildEmptyMenu()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: menu.length,
                      itemBuilder: (context, index) =>
                          _MenuDishCard(dish: menu[index]),
                    ),
            ),

            // ── Action buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Start service day
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: menu.isEmpty ? null : () {
                        // TODO: Start service day
                        GameAudioService().playSfx(GameSfx.doorOpen);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8A0BF),
                        foregroundColor: const Color(0xFF3D2B1F),
                        disabledBackgroundColor: Colors.grey.shade800,
                        disabledForegroundColor: Colors.grey.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        '🏪 Open for Service!',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Travel to discover
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              GameAudioService().playSfx(GameSfx.mapTap);
                              // TODO: Navigate to map
                            },
                            icon: const Text('🗾', style: TextStyle(fontSize: 16)),
                            label: const Text('Travel'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD4A574),
                              side: BorderSide(
                                color: const Color(0xFFD4A574).withAlpha(80),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Add new dish
                      Expanded(
                        child: SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              game.showOverlay(GameOverlay.camera);
                            },
                            icon: const Text('📸', style: TextStyle(fontSize: 16)),
                            label: const Text('Add Ramen'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB8A9C9),
                              side: BorderSide(
                                color: const Color(0xFFB8A9C9).withAlpha(80),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMenu() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🍜', style: TextStyle(fontSize: 60)),
          SizedBox(height: 12),
          Text(
            'No dishes yet!',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Take a photo of ramen to add it.',
            style: TextStyle(color: Colors.white30, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});

  final String icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuDishCard extends StatelessWidget {
  const _MenuDishCard({required this.dish});

  final Dish dish;

  @override
  Widget build(BuildContext context) {
    final rarityColor = switch (dish.rarityTier) {
      1 => Colors.grey.shade400,
      2 => Colors.blue.shade400,
      3 => Colors.purple.shade400,
      4 => Colors.amber.shade400,
      _ => Colors.grey.shade400,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            rarityColor.withAlpha(25),
            Colors.black.withAlpha(100),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rarityColor.withAlpha(60),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Bowl sprite
          Image.asset(
            'assets/${GameAssetService.bowlSprite(dish.brothBase)}',
            width: 56,
            height: 56,
            errorBuilder: (_, __, ___) =>
                const Text('🍜', style: TextStyle(fontSize: 36)),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dish.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dish.regionalStyle,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

          // Price
          if (dish.price != null)
            Text(
              '¥${dish.price}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
