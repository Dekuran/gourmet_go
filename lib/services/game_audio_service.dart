import 'dart:convert';
import 'dart:typed_data';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Manages all game audio: background music, SFX, and runtime TTS voice.
///
/// Music and SFX use [FlameAudio] static API (asset-based).
/// Voice/TTS uses a raw [AudioPlayer] for byte-based playback since
/// FlameAudio's static methods only support named asset sources.
class GameAudioService {
  static final GameAudioService _instance = GameAudioService._();
  factory GameAudioService() => _instance;
  GameAudioService._();

  // AudioPlayer from flame_audio re-export — needed for byte-based TTS
  final _voicePlayer = AudioPlayer();

  bool _muted = false;
  bool get muted => _muted;

  static const String _elevenLabsBase = 'https://api.elevenlabs.io/v1';
  static const String _voiceId = 'CwhRBWXzGAHq8TQ4Fs17';

  String get _elevenKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  Future<void> playMapMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_map.mp3');
    } catch (e) {
      print('GameAudio: map music not available ($e)');
    }
  }

  Future<void> playShopMusic() async {
    if (_muted) return;
    try {
      await FlameAudio.bgm.stop();
      await FlameAudio.bgm.play('music_shop.mp3');
    } catch (e) {
      print('GameAudio: shop music not available ($e)');
    }
  }

  Future<void> stopMusic() => FlameAudio.bgm.stop();

  Future<void> playSfx(GameSfx sfx) async {
    if (_muted) return;
    try {
      await FlameAudio.play(sfx.filename);
    } catch (_) {}
  }

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
      if (response.statusCode == 200) {
        await _voicePlayer.stop();
        await _voicePlayer.play(BytesSource(response.bodyBytes));
        return true;
      }
      return false;
    } catch (e) {
      print('GameAudio: TTS exception $e');
      return false;
    }
  }

  Future<void> stopVoice() => _voicePlayer.stop();

  Future<Uint8List?> generateSfx(String prompt, {double durationSeconds = 1.0}) async {
    if (_elevenKey.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse('$_elevenLabsBase/sound-generation'),
        headers: {'Content-Type': 'application/json', 'xi-api-key': _elevenKey},
        body: jsonEncode({'text': prompt, 'duration_seconds': durationSeconds, 'prompt_influence': 0.4}),
      );
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }

  void toggleMute() => _muted = !_muted;
}

enum GameSfx {
  mapTap('sfx_map_tap.mp3'),
  chefWalk('sfx_chef_walk.mp3'),
  doorOpen('sfx_door_open.mp3'),
  arrive('sfx_arrive.mp3'),
  photo('sfx_photo.mp3'),
  regionHover('sfx_region_hover.mp3');

  final String filename;
  const GameSfx(this.filename);
}
