import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Generates and in-memory caches all game sprites/backgrounds using Gemini.
///
/// Art direction: isometric false-3D, vibrant flat colours, bold outlines,
/// modern casual game aesthetic — no traditional Japanese cultural symbols.
class GameAssetService {
  static final GameAssetService _instance = GameAssetService._();
  factory GameAssetService() => _instance;
  GameAssetService._();

  final _cache = <String, Uint8List>{};

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _model = 'gemini-2.0-flash-preview-image-generation';

  static const String _styleGuide =
      'Isometric false-3D casual mobile game art. '
      'Vibrant flat colours with soft drop-shadow depth. Bold clean outlines. '
      'Modern indie game aesthetic — fun and expressive without being childish. '
      'NO traditional Japanese cultural symbols: no torii gates, no cherry blossoms, '
      'no tatami mats, no ukiyo-e style. Warm rich colour palette.';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  Future<Uint8List?> getChefSprite() => _generate(
        'chef_sprite',
        'Cartoon chef character sprite, full body, front-facing, chibi proportions. '
        'Round friendly face with big expressive eyes and a warm smile. '
        'Modern white chef coat with bright orange piping and buttons, tilted white toque hat. '
        'Short stubby arms and legs, neutral happy walking pose. '
        'Isolated on solid bright green #00FF00 background for chroma key. '
        '$_styleGuide',
      );

  Future<Uint8List?> getChefPortrait() => _generate(
        'chef_portrait',
        'Close-up bust portrait of a cartoon chef guide character. '
        'Round friendly face, large warm expressive eyes, enthusiastic raised-eyebrow expression. '
        'Modern white chef coat with orange trim, tilted white toque. '
        'Warm rim lighting, slight vignette. Good for visual novel dialogue panel. '
        '$_styleGuide',
      );

  Future<Uint8List?> getRamenBowl(String regionId) {
    final (label, details) = _ramenDetails(regionId);
    return _generate(
      'ramen_bowl_$regionId',
      'Game item icon: a steaming bowl of $label. '
      '$details '
      'Viewed from slightly above at isometric angle, two wispy steam curls rising. '
      'White or transparent background, no scene context, icon-style composition. '
      '$_styleGuide',
    );
  }

  Future<Uint8List?> getShopBackground(String regionId) {
    final desc = _shopDesc(regionId);
    return _generate(
      'shop_bg_$regionId',
      'Interior background art for a ramen restaurant, wide landscape format. '
      '$desc '
      'No characters or people visible. Warm inviting light. No text, no readable signs. '
      '$_styleGuide',
    );
  }

  (String, String) _ramenDetails(String regionId) => switch (regionId) {
        'hokkaido' => (
            'Hokkaido miso ramen',
            'Rich amber miso broth, golden sweet corn kernels, pat of butter melting on surface, '
                'thick wavy noodles, chashu pork slices, spring onions, served in a wide white bowl with blue rim.',
          ),
        'kanto' => (
            'Tokyo shoyu ramen',
            'Clear deep-amber soy sauce broth, thin straight noodles, rolled chashu pork, '
                'halved soft-boiled egg showing orange yolk, sheet of nori, bamboo shoots, spring onions.',
          ),
        'kansai' => (
            'Osaka shio ramen',
            'Crystal-clear pale golden salt broth, thin noodles, white poached chicken slices, '
                'delicate yuzu zest garnish, thin spring onion rings, elegant minimalist presentation.',
          ),
        _ => (
            'Fukuoka tonkotsu ramen',
            'Opaque creamy white pork-bone broth, ultra-thin straight noodles, '
                'pink chashu pork, halved soft egg, red pickled ginger, black garlic oil drizzle, sesame seeds.',
          ),
      };

  String _shopDesc(String regionId) => switch (regionId) {
        'hokkaido' =>
          'Cosy rustic Hokkaido ramen shop interior. Warm wooden beams and worn timber counter, '
              'snowflakes visible through a frosted window, orange paper lanterns glowing overhead, '
              'four counter seats, giant steaming stockpot behind the pass.',
        'kanto' =>
          'Modern Tokyo ramen bar. Clean concrete-and-timber interior, bright pendant lighting, '
              'a long sleek counter with eight stools, subtle neon accent strips, open kitchen visible in back.',
        'kansai' =>
          'Elegant Osaka ramen restaurant. Light natural wood panelling, zen-minimal layout, '
              'soft diffused ambient lighting, low counter with wooden stools, small potted plants, serene and airy.',
        _ =>
          'Authentic Fukuoka ramen yatai stall at night. Rustic worn-timber counter open on three sides, '
              'warm glowing paper lanterns, dark night sky beyond, billowing steam from large pots, three bar stools.',
      };

  Future<Uint8List?> _generate(String key, String prompt) async {
    if (_cache.containsKey(key)) return _cache[key];
    if (_apiKey.isEmpty) {
      print('GameAssetService: no GEMINI_API_KEY');
      return null;
    }

    try {
      final url = '$_baseUrl/models/$_model:generateContent?key=$_apiKey';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
              ],
            },
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE'],
          },
        }),
      );

      if (response.statusCode != 200) {
        print('GameAssetService [$key] error ${response.statusCode}');
        return null;
      }

      final bytes = _extractImageBytes(response.body);
      if (bytes != null) {
        _cache[key] = bytes;
        print('GameAssetService [$key]: ${bytes.length} bytes cached');
      }
      return bytes;
    } catch (e) {
      print('GameAssetService [$key] exception: $e');
      return null;
    }
  }

  Uint8List? _extractImageBytes(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;
      final content = candidates[0]['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;
      if (parts == null) return null;
      for (final part in parts) {
        if (part is Map && part.containsKey('inlineData')) {
          final b64 = (part['inlineData'] as Map)['data'] as String?;
          if (b64 != null) return base64Decode(b64);
        }
      }
      return null;
    } catch (e) {
      print('GameAssetService: failed to extract image bytes: $e');
      return null;
    }
  }
}
