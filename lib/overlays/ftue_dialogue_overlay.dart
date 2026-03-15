import 'package:flutter/material.dart';

import '../game/gourmet_go_game.dart';
import '../game/scenes/ftue_scene.dart';
import '../services/debug_logger.dart';
import '../services/ftue_service.dart';
import '../services/game_asset_service.dart';
import '../services/game_audio_service.dart';

/// FTUE sous-chef dialogue overlay.
///
/// Displays the sous chef portrait and dialogue text at the bottom
/// of the screen over the dark kitchen Flame scene. Drives the
/// conversation forward with tap-to-advance, plays TTS for each line,
/// and signals scene transitions.
class FtueDialogueOverlay extends StatefulWidget {
  const FtueDialogueOverlay({required this.game, super.key});

  final GourmetGoGame game;

  @override
  State<FtueDialogueOverlay> createState() => _FtueDialogueOverlayState();
}

class _FtueDialogueOverlayState extends State<FtueDialogueOverlay>
    with SingleTickerProviderStateMixin {
  static final _log = DebugLogger.instance;
  static final _audio = GameAudioService();

  int _lineIndex = 0;
  bool _speaking = false;
  SousChefMood _mood = SousChefMood.neutral;

  /// Dialogue script — matches restaurant_sim_prototype.md §4 FTUE script.
  static const _lines = [
    _Line(
      '...Ah! You\'re here! Welcome, welcome!',
      SousChefMood.excited,
      darkness: 0.7,
    ),
    _Line(
      'I\'m Miso — your sous chef. This old kitchen has been waiting for someone special.',
      SousChefMood.neutral,
      darkness: 0.6,
    ),
    _Line(
      'You know what makes a great ramen chef? It\'s not just skill in the kitchen...',
      SousChefMood.thinking,
      darkness: 0.5,
    ),
    _Line(
      'It\'s the journey. Travelling across Japan, tasting every bowl, discovering regional secrets.',
      SousChefMood.excited,
      darkness: 0.35,
    ),
    _Line(
      'Every bowl has a story. Every region has a style. And every photograph unlocks a new recipe.',
      SousChefMood.neutral,
      darkness: 0.2,
    ),
    _Line(
      'So let\'s start! Show me a bowl of ramen — snap a photo and I\'ll tell you everything about it!',
      SousChefMood.excited,
      darkness: 0.0,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _playCurrentLine();
    _audio.playFtueIntroMusic();
    _audio.playSfx(GameSfx.kitchenAmbience);
    FtueService.instance.saveStep(FtueStep.intro);
  }

  void _playCurrentLine() async {
    if (_lineIndex >= _lines.length) return;

    final line = _lines[_lineIndex];
    setState(() {
      _mood = line.mood;
      _speaking = true;
    });

    // Adjust kitchen darkness
    final scene = widget.game.world;
    if (scene is FtueScene) {
      scene.setDarknessOpacity(line.darkness);
    }

    // TTS
    await _audio.speakLine(line.text);
    if (mounted) setState(() => _speaking = false);
  }

  void _advance() {
    if (_speaking) {
      _audio.stopVoice();
      setState(() => _speaking = false);
      return;
    }

    if (_lineIndex < _lines.length - 1) {
      setState(() => _lineIndex++);
      _playCurrentLine();
    } else {
      // End of dialogue — transition to camera
      _log.logInfo('FtueDialogue', 'Dialogue complete, opening camera');
      FtueService.instance.saveStep(FtueStep.camera);
      widget.game.hideOverlay(GameOverlay.ftue);
      widget.game.showOverlay(GameOverlay.camera);
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = _lineIndex < _lines.length ? _lines[_lineIndex] : null;

    return GestureDetector(
      onTap: _advance,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Sous chef portrait
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Image.asset(
                'assets/${GameAssetService.sousChefPortrait(_mood)}',
                width: 120,
                height: 120,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 120,
                  height: 120,
                  child: Icon(Icons.person, size: 60, color: Colors.white54),
                ),
              ),
            ),

            // Dialogue box
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.deepOrange.withAlpha(100),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Chef name
                  Text(
                    'Miso 🍜',
                    style: TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Dialogue text
                  Text(
                    line?.text ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Tap indicator
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _speaking ? '⏸ tap to skip' : '▶ tap to continue',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Dialogue line with mood and darkness level.
class _Line {
  const _Line(this.text, this.mood, {this.darkness = 0.5});
  final String text;
  final SousChefMood mood;
  final double darkness;
}
