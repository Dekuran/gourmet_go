import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../models/customer_order.dart';
import 'customer_entity.dart';

/// A speech bubble above a customer showing their dish order.
///
/// Tapping this bubble assigns the order to the chef.
/// Includes a "Tap!" hint to help the player understand interaction.
class SpeechBubbleComponent extends PositionComponent with TapCallbacks {
  SpeechBubbleComponent({required this.order, required this.customer})
      : super(
          position: Vector2(-25, -58),
          size: Vector2(120, 48),
        );

  final CustomerOrder order;
  final CustomerEntity customer;

  static const _bg = Color(0xFFFFFDE7);
  static const _border = Color(0xFFFF6B35);
  static const _text = Color(0xFF1A1A1A);
  static const _hintColor = Color(0xFFFF6B35);

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = _bg;
    final borderPaint = Paint()
      ..color = _border
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Rounded rectangle bubble
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    // Small triangle pointer at bottom-center
    final pointerPath = Path()
      ..moveTo(size.x / 2 - 6, size.y)
      ..lineTo(size.x / 2, size.y + 8)
      ..lineTo(size.x / 2 + 6, size.y)
      ..close();
    canvas.drawPath(pointerPath, Paint()..color = _bg);
    canvas.drawPath(
      pointerPath,
      Paint()
        ..color = _border
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // Dish name (first line)
    final nameBuilder = ParagraphBuilder(
      ParagraphStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.center,
        ellipsis: '…',
        maxLines: 1,
      ),
    )
      ..pushStyle(TextStyle(color: _text))
      ..addText(order.dish.name);

    final nameParagraph = nameBuilder.build()
      ..layout(ParagraphConstraints(width: size.x - 8));
    canvas.drawParagraph(nameParagraph, const Offset(4, 6));

    // "👆 Tap to cook!" hint (second line)
    final hintBuilder = ParagraphBuilder(
      ParagraphStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        textAlign: TextAlign.center,
        maxLines: 1,
      ),
    )
      ..pushStyle(TextStyle(color: _hintColor))
      ..addText('👆 Tap to cook!');

    final hintParagraph = hintBuilder.build()
      ..layout(ParagraphConstraints(width: size.x - 8));
    canvas.drawParagraph(hintParagraph, const Offset(4, 24));
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    customer.onBubbleTapped();
  }
}
