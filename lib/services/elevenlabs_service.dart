import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// ElevenLabs Text-to-Speech service.
/// Generates MP3 audio from text narration for the ramen guide.
class ElevenLabsService {
  static const String _baseUrl = 'https://api.elevenlabs.io/v1';

  // Roger — warm, authoritative male voice, good for a ramen master
  static const String _defaultVoiceId = 'CwhRBWXzGAHq8TQ4Fs17';

  String get _apiKey => dotenv.env['ELEVENLABS_API_KEY'] ?? '';

  /// Generate speech audio from text.
  /// Returns raw MP3 bytes ready for playback.
  /// Never throws — returns null on failure.
  Future<Uint8List?> generateSpeech(
    String text, {
    String? voiceId,
    String model = 'eleven_multilingual_v2',
    double stability = 0.5,
    double similarityBoost = 0.75,
  }) async {
    if (_apiKey.isEmpty) {
      print('ElevenLabsService: no API key');
      return null;
    }

    final voice = voiceId ?? _defaultVoiceId;
    final url = '$_baseUrl/text-to-speech/$voice';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': _apiKey,
        },
        body: jsonEncode({
          'text': text,
          'model_id': model,
          'voice_settings': {
            'stability': stability,
            'similarity_boost': similarityBoost,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('ElevenLabs TTS: ${response.bodyBytes.length} bytes generated');
        return response.bodyBytes;
      }

      print('ElevenLabs TTS error ${response.statusCode}: ${response.body}');
      return null;
    } catch (e) {
      print('ElevenLabs TTS exception: $e');
      return null;
    }
  }

  /// Get available voices (for debugging/selection)
  Future<List<Map<String, dynamic>>> getVoices() async {
    if (_apiKey.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {'xi-api-key': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final voices = data['voices'] as List? ?? [];
        return voices.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('ElevenLabs voices error: $e');
      return [];
    }
  }
}
