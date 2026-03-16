import 'dart:developer' as developer;

import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/gourmet_go_game.dart';
import 'overlays/camera_overlay.dart';
import 'overlays/dish_reveal_overlay.dart';
import 'overlays/ftue_dialogue_overlay.dart';
import 'overlays/hud_overlay.dart';
import 'overlays/shop_overlay.dart';
import 'screens/api_test_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow both portrait and landscape orientations.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Load .env for API keys.
  await dotenv.load(fileName: '.env');

  developer.log('main: dotenv loaded', name: 'gourmet_go');

  runApp(
    const ProviderScope(
      child: GourmetGoApp(),
    ),
  );
}

/// Top-level app widget.
///
/// Wraps a [RiverpodAwareGameWidget] inside a [MaterialApp] so
/// that Flutter overlays (camera, menus, dialogue panels) can use
/// Material widgets and theme data. The [RiverpodAwareGameWidget]
/// bridges Riverpod providers into the Flame game engine via
/// [RiverpodGameMixin] on [GourmetGoGame].
class GourmetGoApp extends StatefulWidget {
  const GourmetGoApp({super.key});

  @override
  State<GourmetGoApp> createState() => _GourmetGoAppState();
}

class _GourmetGoAppState extends State<GourmetGoApp> {
  late final GourmetGoGame _game;
  final _gameWidgetKey =
      GlobalKey<RiverpodAwareGameWidgetState<GourmetGoGame>>();

  /// When true, shows the legacy API test screen instead
  /// of the Flame game. Toggle via the debug FAB.
  bool _showApiTest = false;

  @override
  void initState() {
    super.initState();
    _game = GourmetGoGame();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gourmet Go',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepOrange,
          secondary: Colors.amber,
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: _showApiTest ? const ApiTestScreen() : _buildGameView(),
    );
  }

  Widget _buildGameView() {
    return Scaffold(
      body: RiverpodAwareGameWidget<GourmetGoGame>(
        key: _gameWidgetKey,
        game: _game,
        loadingBuilder: (_) => const _LoadingScreen(),
        errorBuilder: (context, error) => _ErrorScreen(error: error),
        overlayBuilderMap: {
          // ── FTUE ──
          GameOverlay.ftue.name: (context, game) =>
              FtueDialogueOverlay(game: game),
          GameOverlay.sousChefBubble.name: (context, game) =>
              _placeholder('Sous Chef Bubble'),

          // ── Camera / Recognition ──
          GameOverlay.camera.name: (context, game) =>
              CameraOverlay(game: game),
          GameOverlay.dishReveal.name: (context, game) =>
              DishRevealOverlay(game: game),
          GameOverlay.starterPicker.name: (context, game) =>
              _placeholder('Starter Picker'),

          // ── Map ──
          GameOverlay.mapInfo.name: (context, game) =>
              _placeholder('Map Info'),

          // ── Shop / Service ──
          GameOverlay.shop.name: (context, game) =>
              ShopOverlay(game: game),
          GameOverlay.hud.name: (context, game) =>
              HudOverlay(game: game),
          GameOverlay.menuBoard.name: (context, game) =>
              _placeholder('Menu Board'),
          GameOverlay.daySummary.name: (context, game) =>
              _placeholder('Day Summary'),
          GameOverlay.upgrade.name: (context, game) =>
              _placeholder('Upgrade'),

          // ── Dev tools ──
          GameOverlay.apiTest.name: (context, game) =>
              const ApiTestScreen(),
        },
      ),

      // Debug FAB to toggle API test screen during development.
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'debug_toggle',
        backgroundColor: Colors.deepOrange.withAlpha(180),
        onPressed: () => setState(() => _showApiTest = !_showApiTest),
        child: Icon(
          _showApiTest ? Icons.gamepad : Icons.science,
          size: 20,
        ),
      ),
    );
  }

  /// Temporary overlay placeholder used until real overlay
  /// widgets are implemented in later phases.
  Widget _placeholder(String label) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '[$label overlay — coming soon]',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Full-screen loading indicator shown while the Flame game
/// engine initialises.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0F0F1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🍜',
              style: TextStyle(fontSize: 48),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(
              color: Colors.deepOrange,
            ),
            SizedBox(height: 12),
            Text(
              'Preparing the kitchen...',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error fallback shown if the Flame game fails to load.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF0F0F1A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to start the game',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
