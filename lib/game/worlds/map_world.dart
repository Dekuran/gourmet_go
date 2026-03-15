import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle;

import '../../models/region.dart';
import '../gourmet_go_game.dart';
import '../components/map/region_node.dart';

/// The Japan map world showing 4 tappable region nodes.
///
/// Tapping a region opens the [GameOverlay.mapInfo] overlay.
class MapWorld extends World {
  MapWorld({required this.game});

  final GourmetGoGame game;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Dark map background.
    final bg = RectangleComponent(
      size: game.size,
      paint: Paint()..color = const Color(0xFF0A1628),
    );
    add(bg);

    // Japan map title text.
    final title = TextComponent(
      text: 'Japan — Choose a Region',
      position: Vector2(game.size.x / 2, 24),
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
}
