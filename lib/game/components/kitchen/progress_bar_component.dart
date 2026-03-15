import 'dart:ui';

import 'package:flame/components.dart';

/// A horizontal progress bar rendered on the canvas.
///
/// Set [progress] (0.0–1.0) to update the fill.
class ProgressBarComponent extends PositionComponent {
  ProgressBarComponent({
    required Vector2 position,
    required Vector2 size,
    Color fillColor = const Color(0xFFFF6B35),
    Color bgColor = const Color(0xFF333333),
  })  : _fillColor = fillColor,
        _bgColor = bgColor,
        super(position: position, size: size);

  final Color _fillColor;
  final Color _bgColor;

  double _progress = 0.0;

  /// Fill amount from 0.0 (empty) to 1.0 (full).
  double get progress => _progress;
  set progress(double value) => _progress = value.clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = _bgColor;
    final fillPaint = Paint()..color = _fillColor;

    final bgRect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(bgRect, bgPaint);

    final fillRect = Rect.fromLTWH(0, 0, size.x * _progress, size.y);
    canvas.drawRect(fillRect, fillPaint);
  }
}
