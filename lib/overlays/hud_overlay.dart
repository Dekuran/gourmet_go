import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/gourmet_go_game.dart';
import '../providers/game_providers.dart';
import '../services/game_audio_service.dart';

/// Heads-up display overlay — cash, day counter, mute toggle.
///
/// Shown atop the Flame game during map and shop scenes.
/// Reads [cashProvider] and [dayProvider] from Riverpod.
class HudOverlay extends ConsumerWidget {
  const HudOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cash = ref.watch(cashProvider);
    final day = ref.watch(dayProvider);
    final phase = ref.watch(gamePhaseProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // ── Cash ──
            _HudChip(
              icon: '🪙',
              label: '$cash credits',
              color: Colors.amber,
            ),
            const SizedBox(width: 8),

            // ── Day ──
            _HudChip(
              icon: '📅',
              label: 'Day $day',
              color: Colors.white70,
            ),
            const SizedBox(width: 8),

            // ── Phase indicator ──
            _HudChip(
              icon: _phaseIcon(phase),
              label: _phaseLabel(phase),
              color: Colors.deepOrange,
            ),

            const Spacer(),

            // ── Camera button (re-enter camera from map) ──
            if (phase == GamePhase.map)
              _HudIconButton(
                icon: Icons.camera_alt,
                tooltip: 'Snap a bowl',
                onTap: () => game.showOverlay(GameOverlay.camera),
              ),

            const SizedBox(width: 4),

            // ── Mute toggle ──
            _HudIconButton(
              icon: GameAudioService().muted
                  ? Icons.volume_off
                  : Icons.volume_up,
              tooltip: 'Toggle sound',
              onTap: () => GameAudioService().toggleMute(),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseIcon(GamePhase phase) => switch (phase) {
        GamePhase.ftue => '🎓',
        GamePhase.map => '🗾',
        GamePhase.shop => '🍜',
        GamePhase.daySummary => '⭐',
        GamePhase.upgrade => '⬆️',
      };

  String _phaseLabel(GamePhase phase) => switch (phase) {
        GamePhase.ftue => 'Tutorial',
        GamePhase.map => 'Map',
        GamePhase.shop => 'Service',
        GamePhase.daySummary => 'Summary',
        GamePhase.upgrade => 'Upgrade',
      };
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final String icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(150),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(40)),
          ),
          child: Icon(icon, color: Colors.white70, size: 18),
        ),
      ),
    );
  }
}
