import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/line_cook.dart';

class LineCookService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';

  static const List<String> _validTags = [
    'fermented', 'regional', 'fish', 'pork', 'rich', 'delicate',
    'street_food', 'umami', 'pressed', 'smoky', 'crispy', 'rare',
    'photogenic', 'comfort', 'seasonal',
  ];

  static const String _prompt = '''
Generate ONE Japanese ramen kitchen line chef as a JSON object.
They should specialize in a regional ramen style (tonkotsu, miso, shoyu, shio, etc.).
Return ONLY valid JSON, no preamble, no markdown.
Schema:
{
  "name": "",
  "specialty_regions": ["region1", "region2"],
  "strength_tags": ["tag1", "tag2", "tag3"],
  "weakness_tags": ["tag1", "tag2"],
  "personality": "one_word",
  "backstory": "one sentence about their ramen cooking background"
}
Regions must be from: Kanto, Kansai, Hokkaido, Kyushu, Tohoku
Tags must be from: fermented|regional|fish|pork|rich|delicate|street_food|umami|pressed|smoky|crispy|rare|photogenic|comfort|seasonal''';

  String get _apiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': _apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// Generates a random line cook using Claude.
  /// Falls back to LineCook.fixture() on any error.
  Future<LineCook> generateChef() async {
    try {
      final body = jsonEncode({
        'model': _model,
        'max_tokens': 256,
        'messages': [
          {'role': 'user', 'content': _prompt},
        ],
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: _headers,
        body: body,
      );

      if (response.statusCode != 200) {
        return LineCook.fixture();
      }

      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      if (content.isEmpty) return LineCook.fixture();

      final responseText = content[0]['text'] as String;
      return _parseLineCook(responseText);
    } catch (e) {
      return LineCook.fixture();
    }
  }

  LineCook _parseLineCook(String responseText) {
    try {
      final cook = LineCook.fromJson(jsonDecode(responseText));
      return _filterTags(cook);
    } catch (e) {
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (match != null) {
        try {
          final cook = LineCook.fromJson(jsonDecode(match.group(0)!));
          return _filterTags(cook);
        } catch (_) {}
      }
      return LineCook.fixture();
    }
  }

  LineCook _filterTags(LineCook cook) {
    return LineCook(
      name: cook.name,
      specialtyRegions: cook.specialtyRegions,
      strengthTags:
          cook.strengthTags.where((t) => _validTags.contains(t)).toList(),
      weaknessTags:
          cook.weaknessTags.where((t) => _validTags.contains(t)).toList(),
      personality: cook.personality,
      backstory: cook.backstory,
    );
  }
}
