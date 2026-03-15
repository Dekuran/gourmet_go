import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../game/worlds/shop_world.dart';
import '../models/region.dart';
import '../providers/game_providers.dart';

/// Bottom-sheet overlay showing a region's details and "Enter Shop" CTA.
///
/// Reads [GourmetGoGame.pendingRegionId] set by [RegionNode] on tap.
class MapInfoOverlay extends ConsumerWidget {
  const MapInfoOverlay({super.key, required this.game});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final regionId = game.pendingRegionId;
    if (regionId == null) return const SizedBox.shrink();
    final region = Region.byId(regionId);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: region.primaryColor.withAlpha(100)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RegionHeader(region: region),
            const SizedBox(height: 12),
            Text(
              region.ramenDescription,
              style: TextStyle(
                color: region.primaryColor,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              region.arrivalQuote,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => game.closeMapInfo(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      ref
                          .read(regionUnlockProvider.notifier)
                          .unlock(regionId);
                      game.switchScene(ShopWorld(game: game), 'shop');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: region.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Enter Shop'),
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

class _RegionHeader extends StatelessWidget {
  const _RegionHeader({required this.region});

  final Region region;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(region.ramenEmoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              region.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${region.prefecture} · ${region.ramenType}',
              style: TextStyle(color: region.primaryColor, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }
}
