import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../../models/region.dart';
import '../../providers/game_providers.dart';
import '../gourmet_go_game.dart';
import '../components/map/region_node.dart';

/// The Japan map world showing 4 tappable region nodes.
///
/// Tapping a region opens the [GameOverlay.mapInfo] overlay.
///
/// Uses the camera's fixed-resolution viewport (960×540) centred at (0, 0).
class MapWorld extends World {
  MapWorld({required this.game});

  final GourmetGoGame game;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;

    // Dark map background — centred at origin.
    final bg = RectangleComponent(
      size: Vector2(viewW, viewH),
      position: Vector2(-halfW, -halfH),
      paint: Paint()..color = const Color(0xFF0A1628),
    );
    add(bg);

    // Japan map title text.
    final title = TextComponent(
      text: 'Japan — Choose a Region',
      position: Vector2(0, -halfH + 24),
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    add(title);

    // Add a node for each region.
    for (final region in Region.all) {
      add(RegionNode(region: region, game: game));
    }
  }

  @override
  void onMount() {
    super.onMount();
    game.ref.read(gamePhaseProvider.notifier).set(GamePhase.map);
    game.showHud();
  }

  @override
  void onRemove() {
    game.hideHud();
    super.onRemove();
  }
}
