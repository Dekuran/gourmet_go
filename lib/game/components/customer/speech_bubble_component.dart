import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../../../models/customer_order.dart';
import 'customer_entity.dart';

/// A speech bubble above a customer showing their dish order.
///
/// Tapping this bubble assigns the order to the chef.
class SpeechBubbleComponent extends PositionComponent with TapCallbacks {
  SpeechBubbleComponent({required this.order, required this.customer})
      : super(
          position: Vector2(-20, -50),
          size: Vector2(120, 36),
        );

  final CustomerOrder order;
  final CustomerEntity customer;

  static const _bg = Color(0xFFFFFDE7);
  static const _border = Color(0xFFFF6B35);
  static const _text = Color(0xFF1A1A1A);

  @override
  void render(Canvas canvas) {
    final bgPaint = Paint()..color = _bg;
    final borderPaint = Paint()
      ..color = _border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    final paragraphBuilder = ParagraphBuilder(
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

    final paragraph = paragraphBuilder.build()
      ..layout(ParagraphConstraints(width: size.x - 8));

    canvas.drawParagraph(paragraph, const Offset(4, 10));
  }

  @override
  void onTapDown(TapDownEvent event) {
    event.handled = true;
    customer.onBubbleTapped();
  }
}
