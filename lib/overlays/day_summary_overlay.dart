import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../providers/customer_queue_provider.dart';
import '../providers/game_providers.dart';

/// End-of-day overlay showing star rating, served/missed counts,
/// and a sous-chef debrief line. "Continue" advances to the upgrade overlay.
class DaySummaryOverlay extends ConsumerWidget {
  const DaySummaryOverlay({super.key, required this.game});

  final GourmetGoGame game;

  static int calcStars(int served, int total) {
    if (total == 0) return 1;
    final rate = served / total;
    if (rate >= 0.9) return 5;
    if (rate >= 0.75) return 4;
    if (rate >= 0.5) return 3;
    if (rate >= 0.25) return 2;
    return 1;
  }

  static String debrief(int stars) => switch (stars) {
        5 => 'Incredible! Not a single customer left unhappy. The queue sang!',
        4 => 'Great shift. A few orders slipped through — regulars are coming back.',
        3 => 'Decent day. We kept pace but the queue tested us.',
        2 => 'Rough service — patience ran thin and orders backed up.',
        _ => 'Ken was overwhelmed. We need faster hands tomorrow.',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueNotifier = ref.read(customerQueueProvider.notifier);
    final served = queueNotifier.servedCount;
    final missed = queueNotifier.missedCount;
    final total = served + missed;
    final stars = calcStars(served, total);
    final day = ref.watch(dayProvider);

    return Scaffold(
      backgroundColor: const Color(0xCC000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Text(
                'Day $day — End of Service',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 28),
              _StarRow(stars: stars),
              const SizedBox(height: 12),
              Text(
                debrief(stars),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 36),
              _StatRow(label: 'Served', value: served, color: Colors.greenAccent),
              const SizedBox(height: 10),
              _StatRow(label: 'Missed', value: missed, color: Colors.redAccent),
              const SizedBox(height: 10),
              _StatRow(label: 'Total customers', value: total, color: Colors.white54),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  game.hideOverlay(GameOverlay.daySummary);
                  game.showOverlay(GameOverlay.upgrade);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue →',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (i) => Icon(
          i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber,
          size: 44,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        Text(
          '$value',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
