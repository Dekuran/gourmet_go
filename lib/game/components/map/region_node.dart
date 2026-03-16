import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_riverpod/flame_riverpod.dart';

import '../../../models/region.dart';
import '../../../providers/game_providers.dart';
import '../../gourmet_go_game.dart';

/// A tappable region node on the Japan map.
///
/// Displays as a colored circle; locked regions are dimmed.
/// Tap → shows the [GameOverlay.mapInfo] overlay.
class RegionNode extends PositionComponent
    with TapCallbacks, RiverpodComponentMixin {
  RegionNode({required this.region, required this.game})
      : super(size: Vector2(60, 60));

  final Region region;
  final GourmetGoGame game;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Convert normalised map position (0–1) to world-centred coordinates.
    // Viewport is 960×540 centred at origin, so range is [-480,480] × [-270,270].
    final viewW = game.camera.viewport.size.x;
    final viewH = game.camera.viewport.size.y;
    final halfW = viewW / 2;
    final halfH = viewH / 2;
    position = Vector2(
      region.mapPosition.dx * viewW - halfW - size.x / 2,
      region.mapPosition.dy * viewH - halfH - size.y / 2,
    );
  }

  bool get _isUnlocked =>
      ref.read(regionUnlockProvider)[region.id] ?? false;

  @override
  void render(Canvas canvas) {
    final unlocked = _isUnlocked;
    final baseColor = Color(region.primaryColor.toARGB32());
    final paint = Paint()
      ..color = unlocked ? baseColor : baseColor.withAlpha(100);

    // Circle node.
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      size.x / 2,
      paint,
    );

    // Ramen emoji text.
    final paragraphBuilder = ParagraphBuilder(
      ParagraphStyle(
        fontSize: 22,
        textAlign: TextAlign.center,
      ),
    )..addText(region.ramenEmoji);

    final paragraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: size.x));
    canvas.drawParagraph(paragraph, Offset(0, size.y / 2 - 14));
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    game.showMapInfo(region.id);
  }
}
