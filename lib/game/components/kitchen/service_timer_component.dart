import 'package:flame/components.dart';

import '../../gourmet_go_game.dart';

/// 240-second service day countdown with pause/resume support.
///
/// When it hits zero, triggers [GourmetGoGame.showDaySummary].
class ServiceTimerComponent extends Component {
  ServiceTimerComponent({required this.game});

  static const _dayDuration = 240.0;

  final GourmetGoGame game;

  double _remaining = _dayDuration;
  bool _paused = false;
  bool _ended = false;

  /// Seconds left in the service day (rounded up).
  int get remainingSeconds => _remaining.ceil().clamp(0, _dayDuration.toInt());

  /// Fraction of day remaining (1.0 = start, 0.0 = end).
  double get fraction => _remaining / _dayDuration;

  @override
  void update(double dt) {
    if (_paused || _ended) return;
    _remaining -= dt;
    if (_remaining <= 0) {
      _remaining = 0;
      _ended = true;
      game.showDaySummary();
    }
  }

  void pause() => _paused = true;
  void resume() => _paused = false;

  void reset() {
    _remaining = _dayDuration;
    _paused = false;
    _ended = false;
  }
}
