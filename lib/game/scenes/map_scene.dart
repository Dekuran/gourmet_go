import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../../models/region.dart';
import '../../services/game_audio_service.dart';
import '../gourmet_go_game.dart';

/// Japan map scene — player selects a region to travel to.
///
/// Shows the four regions as tappable markers on a stylised map.
/// Unlocked regions pulse with their primary colour; locked regions
/// are greyed out. Tapping an unlocked region transitions to the
/// shop scene for that region.
class MapScene extends World
    with HasGameReference<GourmetGoGame>, RiverpodComponentMixin {
  final Map<String, _RegionMarker> _markers = {};

  @override
  Future<void> onLoad() async {
    developer.log('MapScene: loading', name: 'gourmet_go.scene');

    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;

    // Dark blue-gradient map background
    final bgPaint = Paint()..color = const Color(0xFF0A1628);
    add(RectangleComponent(
      size: Vector2(viewW, viewH),
      position: Vector2(-halfW, -halfH),
      paint: bgPaint,
      priority: 0,
    ));

    // Add region markers
    for (final region in Region.all) {
      final marker = _RegionMarker(
        region: region,
        gameRef: game,
        viewW: viewW,
        viewH: viewH,
      );
      _markers[region.id] = marker;
      add(marker);
    }

    // Draw connecting paths between regions
    _addConnections(viewW, viewH);

    // Show HUD overlay
    game.showOverlay(GameOverlay.hud);

    // Start map music
    await GameAudioService().playMapMusic();

    developer.log('MapScene: loaded (${viewW}x$viewH)',
        name: 'gourmet_go.scene');
  }

  void _addConnections(double viewW, double viewH) {
    final halfW = viewW / 2;
    final halfH = viewH / 2;
    // Simple connection indicators between linked regions
    for (final region in Region.all) {
      for (final targetId in region.connectedTo) {
        final target = Region.byId(targetId);
        final fromX = region.mapPosition.dx * viewW - halfW;
        final fromY = region.mapPosition.dy * viewH - halfH;
        final toX = target.mapPosition.dx * viewW - halfW;
        final toY = target.mapPosition.dy * viewH - halfH;

        // Midpoint dot as a simple connection indicator
        final midX = (fromX + toX) / 2;
        final midY = (fromY + toY) / 2;
        add(CircleComponent(
          radius: 2,
          paint: Paint()..color = const Color(0x33FFFFFF),
          position: Vector2(midX, midY),
          anchor: Anchor.center,
        ));
      }
    }
  }

  /// Refresh marker unlock states from Riverpod.
  void refreshUnlocks(Map<String, bool> unlockState) {
    for (final entry in unlockState.entries) {
      _markers[entry.key]?.setUnlocked(entry.value);
    }
  }
}

/// Tappable region marker on the Japan map.
class _RegionMarker extends PositionComponent with TapCallbacks {
  _RegionMarker({
    required this.region,
    required this.gameRef,
    required this.viewW,
    required this.viewH,
  });

  final Region region;
  final GourmetGoGame gameRef;
  final double viewW;
  final double viewH;
  bool _unlocked = false;

  late CircleComponent _dot;
  late TextComponent _label;

  @override
  Future<void> onLoad() async {
    // Position based on region's normalized map position
    final halfW = viewW / 2;
    final halfH = viewH / 2;
    final x = region.mapPosition.dx * viewW - halfW;
    final y = region.mapPosition.dy * viewH - halfH;
    position = Vector2(x, y);
    size = Vector2(60, 60);
    anchor = Anchor.center;

    // Marker dot
    _dot = CircleComponent(
      radius: 18,
      paint: Paint()..color = const Color(0xFF444466),
      anchor: Anchor.center,
      position: Vector2(30, 25),
    );
    add(_dot);

    // Ramen emoji
    add(TextComponent(
      text: region.ramenEmoji,
      textRenderer: TextPaint(
        style: TextStyle(fontSize: 16),
      ),
      anchor: Anchor.center,
      position: Vector2(30, 25),
    ));

    // Region name label
    _label = TextComponent(
      text: region.name,
      textRenderer: TextPaint(
        style: TextStyle(
          color: const Color(0xAAFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      anchor: Anchor.topCenter,
      position: Vector2(30, 48),
    );
    add(_label);
  }

  void setUnlocked(bool unlocked) {
    _unlocked = unlocked;
    if (_unlocked) {
      _dot.paint.color = region.primaryColor;
      _label.textRenderer = TextPaint(
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      );
      // Pulse animation for unlocked markers
      _dot.add(
        ScaleEffect.by(
          Vector2.all(1.15),
          EffectController(
            duration: 0.8,
            reverseDuration: 0.8,
            infinite: true,
          ),
        ),
      );
    } else {
      _dot.paint.color = const Color(0xFF444466);
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_unlocked) {
      GameAudioService().playSfx(GameSfx.regionHover);
      return;
    }
    GameAudioService().playSfx(GameSfx.mapTap);

    // Show map info overlay (region details)
    gameRef.showOverlay(GameOverlay.mapInfo);
  }
}
