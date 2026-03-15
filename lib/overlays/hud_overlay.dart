import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../game/worlds/map_world.dart';
import '../providers/game_providers.dart';

/// Heads-up display shown during the service day.
///
/// Shows cash balance, service timer, and bottom bar with
/// camera and map navigation buttons.
class HudOverlay extends ConsumerWidget {
  const HudOverlay({super.key, required this.game});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider);
    final seconds = ref.watch(timerSecondsProvider);
    final mins = seconds ~/ 60;
    final secs = seconds % 60;

    return SafeArea(
      child: Column(
        children: [
          _TopBar(cash: cash, mins: mins, secs: secs, seconds: seconds),
          const Spacer(),
          _BottomBar(game: game),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.cash,
    required this.mins,
    required this.secs,
    required this.seconds,
  });

  final int cash;
  final int mins;
  final int secs;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                '¥',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                ' $cash',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '$mins:${secs.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: seconds < 30 ? Colors.redAccent : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.game});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _HudButton(
            icon: Icons.camera_alt,
            label: 'Camera',
            onTap: () => game.openCamera(),
          ),
          _HudButton(
            icon: Icons.map_outlined,
            label: 'Map',
            onTap: () => game.switchScene(MapWorld(game: game), 'map'),
          ),
        ],
      ),
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
