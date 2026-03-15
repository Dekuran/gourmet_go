import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ReviewService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';

  String get _apiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': _apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// Generates a one-line customer review based on match score.
  /// Falls back to "An interesting experience." on any error.
  Future<String> getReview(
    String customerName,
    String dishName,
    String region,
    double matchScore,
  ) async {
    try {
      final prompt = '''Customer $customerName just ate $dishName from $region at our counter restaurant.
Match score: $matchScore (0.0 to 1.0, where 1.0 is perfect).
Write ONE sentence as their review. 
If score > 0.7: emotional, specific to the region, makes the reader want to visit.
If score 0.4-0.7: politely satisfied, generic.
If score < 0.4: pointed but fair, mentions what was missing.
No quotes around the sentence. Just the sentence.''';

      final body = jsonEncode({
        'model': _model,
        'max_tokens': 80,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: _headers,
        body: body,
      );

      if (response.statusCode != 200) {
        return 'An interesting experience.';
      }

      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      if (content.isEmpty) return 'An interesting experience.';

      final text = (content[0]['text'] as String).trim();
      return text.isNotEmpty ? text : 'An interesting experience.';
    } catch (e) {
      return 'An interesting experience.';
    }
  }
}
