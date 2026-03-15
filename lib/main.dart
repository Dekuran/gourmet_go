import 'dart:developer' as developer;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'game/gourmet_go_game.dart';
import 'screens/api_test_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait on iOS.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
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
/// Wraps a [GameWidget] inside a [MaterialApp] so that
/// Flutter overlays (camera, menus, dialogue panels) can
/// use Material widgets and theme data.
class GourmetGoApp extends StatefulWidget {
  const GourmetGoApp({super.key});

  @override
  State<GourmetGoApp> createState() => _GourmetGoAppState();
}

class _GourmetGoAppState extends State<GourmetGoApp> {
  late final GourmetGoGame _game;

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
      body: GameWidget<GourmetGoGame>(
        game: _game,
        loadingBuilder: (_) => const _LoadingScreen(),
        errorBuilder: (context, error) => _ErrorScreen(error: error),
        overlayBuilderMap: {
          // Each GameOverlay enum value is registered here.
          // Placeholder builders — real widgets added in later
          // phases.
          GameOverlay.dialogue.name: (context, game) =>
              _buildPlaceholderOverlay('Dialogue'),
          GameOverlay.camera.name: (context, game) =>
              _buildPlaceholderOverlay('Camera'),
          GameOverlay.dishReveal.name: (context, game) =>
              _buildPlaceholderOverlay('Dish Reveal'),
          GameOverlay.menuBoard.name: (context, game) =>
              _buildPlaceholderOverlay('Menu Board'),
          GameOverlay.hud.name: (context, game) =>
              _buildPlaceholderOverlay('HUD'),
          GameOverlay.starterPicker.name: (context, game) =>
              _buildPlaceholderOverlay('Starter Picker'),
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
  /// widgets are implemented in Phase 3–4.
  Widget _buildPlaceholderOverlay(String label) {
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
