import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../game/worlds/map_world.dart';
import '../providers/customer_queue_provider.dart';
import '../providers/game_providers.dart';
import '../providers/upgrade_provider.dart';

/// Post-day upgrade overlay.
///
/// Shows Ken's current skill and lets the player spend cash to upgrade.
/// "Next Day" clears the queue, advances the day counter, and returns
/// to the Japan map.
class UpgradeOverlay extends ConsumerWidget {
  const UpgradeOverlay({super.key, required this.game});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chef = ref.watch(chefProvider);
    final cash = ref.watch(cashProvider);
    final canUpgrade = ref.watch(canUpgradeProvider);
    final nextInfo = ref.watch(nextUpgradeInfoProvider);

    return Scaffold(
      backgroundColor: const Color(0xCC000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Between Services',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              _ChefCard(
                name: chef.name,
                skillLabel: chef.skill.label,
                cookTime: chef.cookTimeSeconds,
              ),
              const SizedBox(height: 28),
              if (nextInfo != null) ...[
                _UpgradeSection(
                  nextLabel: nextInfo.label,
                  nextCookTime: nextInfo.level.cookTimeSeconds,
                  cost: nextInfo.cost,
                  cash: cash,
                  canUpgrade: canUpgrade,
                  onUpgrade: () {
                    if (ref.read(cashProvider.notifier).spend(nextInfo.cost)) {
                      ref.read(chefProvider.notifier).upgrade();
                    }
                  },
                ),
              ] else
                const Text(
                  '🏆 Ken has reached Master level!',
                  style: TextStyle(color: Colors.amber, fontSize: 15),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: () {
                  ref.read(dayProvider.notifier).advance();
                  ref.read(customerQueueProvider.notifier).clear();
                  game.switchScene(MapWorld(game: game), 'map');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Next Day →',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChefCard extends StatelessWidget {
  const _ChefCard({
    required this.name,
    required this.skillLabel,
    required this.cookTime,
  });

  final String name;
  final String skillLabel;
  final int cookTime;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          const Text('👨‍🍳', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            skillLabel,
            style: TextStyle(color: Colors.deepOrange.shade300, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Cook time: ${cookTime}s per bowl',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UpgradeSection extends StatelessWidget {
  const _UpgradeSection({
    required this.nextLabel,
    required this.nextCookTime,
    required this.cost,
    required this.cash,
    required this.canUpgrade,
    required this.onUpgrade,
  });

  final String nextLabel;
  final int nextCookTime;
  final int cost;
  final int cash;
  final bool canUpgrade;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Next: $nextLabel — ${nextCookTime}s per bowl',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cost: $cost credits',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Balance: $cash credits',
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: canUpgrade ? onUpgrade : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            disabledBackgroundColor: Colors.grey.shade800,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            canUpgrade ? 'Upgrade Ken — $cost credits' : 'Not enough credits',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
