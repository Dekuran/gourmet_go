import 'dart:convert';
import 'dart:typed_data';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'debug_logger.dart';

/// Manages all game audio: background music, SFX, and runtime TTS voice.
///
/// Music and SFX use [FlameAudio] static API (asset-based).
/// Voice/TTS uses a raw [AudioPlayer] for byte-based playback since
/// FlameAudio's static methods only support named asset sources.
///
/// See [generate_ftue_audio.sh](../../generate_ftue_audio.sh) for the full
/// asset generation script and prompt list.
class GameAudioService {
  static final GameAudioService _instance = GameAudioService._();
  factory GameAudioService() => _instance;
  GameAudioService._();

  static final _log = DebugLogger.instance;

  // AudioPlayer from flame_audio re-export — needed for byte-based TTS
  final _voicePlayer = AudioPlayer();

  bool _muted = false;
  bool get muted => _muted;

  static const String _elevenLabsBase = 'https://api.elevenlabs.io/v1';
  static const String _voiceId = 'CwhRBWXzGAHq8TQ4Fs17';

  String get _elevenKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  // ── Background Music ──────────────────────────────────────────────────────

  /// Play the FTUE intro music (gentle piano + strings, 15s).
  /// Used during the dark-kitchen sous-chef monologue.
  Future<void> playFtueIntroMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_ftue_intro.mp3');
    } catch (e) {
      _log.logError('GameAudio', 'playFtueIntroMusic', '$e');
    }
  }

  /// Play the kitchen / service-day music (warm upbeat, loopable 20s).
  Future<void> playKitchenMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_kitchen.mp3');
    } catch (e) {
      _log.logError('GameAudio', 'playKitchenMusic', '$e');
    }
  }

  Future<void> playMapMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_map.mp3');
    } catch (e) {
      _log.logError('GameAudio', 'playMapMusic', '$e');
    }
  }

  Future<void> playShopMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_shop.mp3');
    } catch (e) {
      _log.logError('GameAudio', 'playShopMusic', '$e');
    }
  }

  Future<void> stopMusic() => FlameAudio.bgm.stop();

  // ── SFX ────────────────────────────────────────────────────────────────────

  Future<void> playSfx(GameSfx sfx) async {
    if (_muted) return;
    try {
      await FlameAudio.play(sfx.filename);
    } catch (_) {}
  }

  // ── TTS (ElevenLabs) ──────────────────────────────────────────────────────

  Future<bool> speakLine(String text) async {
    if (_elevenKey.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('$_elevenLabsBase/text-to-speech/$_voiceId'),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _elevenKey,
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_turbo_v2_5',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.3,
          },
        }),
      );
      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && contentType.contains('audio')) {
        await _voicePlayer.stop();
        await _voicePlayer.play(
          BytesSource(response.bodyBytes, mimeType: 'audio/mpeg'),
        );
        return true;
      }
      _log.logError('GameAudio', 'speakLine', 'HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      _log.logError('GameAudio', 'speakLine', '$e');
      return false;
    }
  }

  Future<void> stopVoice() => _voicePlayer.stop();

  /// Play a pre-baked voice asset from `assets/audio/`.
  ///
  /// Used for FTUE dialogue where TTS was generated ahead of time via
  /// [generate_ftue_dialogue_audio.sh]. Falls back to [speakLine] if the
  /// asset file fails to load.
  Future<bool> playVoiceAsset(String filename) async {
    if (_muted) return false;
    try {
      await _voicePlayer.stop();
      await _voicePlayer.play(AssetSource(filename));
      return true;
    } catch (e) {
      _log.logError('GameAudio', 'playVoiceAsset($filename)', '$e');
      return false;
    }
  }

  // ── Sound Generation (ElevenLabs) ─────────────────────────────────────────

  Future<Uint8List?> generateSfx(
    String prompt, {
    double durationSeconds = 1.0,
  }) async {
    if (_elevenKey.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse('$_elevenLabsBase/sound-generation'),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _elevenKey,
        },
        body: jsonEncode({
          'text': prompt,
          'duration_seconds': durationSeconds,
          'prompt_influence': 0.4,
        }),
      );
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  void toggleMute() {
    _muted = !_muted;
    _log.logInfo('GameAudio', 'Mute toggled: $_muted');
  }
}

/// All SFX assets used by [GameAudioService.playSfx].
///
/// File names must match `assets/audio/` exactly.
/// Generated by [generate_ftue_audio.sh](../../generate_ftue_audio.sh)
/// and [generate_audio.sh](../../generate_audio.sh).
enum GameSfx {
  // ── Original game-loop SFX ──
  mapTap('sfx_map_tap.mp3'),
  chefWalk('sfx_chef_walk.mp3'),
  doorOpen('sfx_door_open.mp3'),
  arrive('sfx_arrive.mp3'),
  photo('sfx_photo.mp3'),
  regionHover('sfx_region_hover.mp3'),

  // ── FTUE + service-day SFX (Phase 1B) ──
  kitchenAmbience('sfx_kitchen_ambience.mp3'),
  dishCardReveal('sfx_dish_card_reveal.mp3'),
  mapPulse('sfx_map_pulse.mp3'),
  customerArrive('sfx_customer_arrive.mp3'),
  orderPlaced('sfx_order_placed.mp3'),
  bowlServed('sfx_bowl_served.mp3'),
  cashDing('sfx_cash_ding.mp3'),
  dayEnd('sfx_day_end.mp3'),
  upgradePurchase('sfx_upgrade_purchase.mp3'),
  starRating('sfx_star_rating.mp3');

  final String filename;
  const GameSfx(this.filename);
}
