import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Gemini image generation service using the Imagen API.
/// Generates images for ramen ingredients.
class GeminiImageService {
  // Gemini 2.5 Flash Image — supports image generation
  static const String _model = 'gemini-2.5-flash-image';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// Generate an image for a single ingredient.
  /// Returns raw image bytes (PNG) or null on failure.
  Future<Uint8List?> generateIngredientImage(String ingredientName) async {
    if (_apiKey.isEmpty) {
      print('GeminiImageService: no API key');
      return null;
    }

    final prompt = 'A beautiful close-up food photography shot of fresh '
        '$ingredientName as a ramen ingredient, on a dark slate surface, '
        'soft warm lighting, shallow depth of field, no text, no labels.';

    try {
      final url =
          '$_baseUrl/models/$_model:generateContent?key=$_apiKey';

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
        print('Gemini image error ${response.statusCode}: ${response.body}');
        return null;
      }

      return _extractImageBytes(response.body);
    } catch (e) {
      print('Gemini image exception: $e');
      return null;
    }
  }

  /// Generate images for multiple ingredients (top 3).
  /// Returns a map of ingredient name -> image bytes.
  Future<Map<String, Uint8List>> generateIngredientImages(
    List<String> ingredients, {
    int maxCount = 3,
  }) async {
    final results = <String, Uint8List>{};
    final toGenerate = ingredients.take(maxCount).toList();

    // Generate sequentially to avoid rate limits
    for (final name in toGenerate) {
      final bytes = await generateIngredientImage(name);
      if (bytes != null) {
        results[name] = bytes;
      }
    }

    return results;
  }

  /// Extract image bytes from Gemini response.
  /// The response contains inlineData with base64-encoded image.
  Uint8List? _extractImageBytes(String responseBody) {
    try {
      final data = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'] as Map<String, dynamic>?;
      if (content == null) return null;

      final parts = content['parts'] as List?;
      if (parts == null) return null;

      // Find the part with inlineData (image)
      for (final part in parts) {
        if (part is Map && part.containsKey('inlineData')) {
          final inlineData = part['inlineData'] as Map<String, dynamic>;
          final b64 = inlineData['data'] as String?;
          if (b64 != null) {
            return base64Decode(b64);
          }
        }
      }

      return null;
    } catch (e) {
      print('Gemini: failed to extract image: $e');
      return null;
    }
  }
}
