import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current phase of the game.
enum GamePhase { ftue, map, shop, postDay }

/// Top-level game state: current phase and day number.
class GameState {
  final GamePhase phase;
  final int dayNumber;

  const GameState({
    this.phase = GamePhase.map,
    this.dayNumber = 1,
  });

  GameState copyWith({GamePhase? phase, int? dayNumber}) => GameState(
        phase: phase ?? this.phase,
        dayNumber: dayNumber ?? this.dayNumber,
      );
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() => const GameState();

  void setPhase(GamePhase phase) {
    state = state.copyWith(phase: phase);
  }

  void nextDay() {
    state = state.copyWith(
      dayNumber: state.dayNumber + 1,
      phase: GamePhase.map,
    );
  }

  void startService() {
    state = state.copyWith(phase: GamePhase.shop);
  }

  void endService() {
    state = state.copyWith(phase: GamePhase.postDay);
  }
}

final gameStateProvider =
    NotifierProvider<GameStateNotifier, GameState>(
  GameStateNotifier.new,
);
