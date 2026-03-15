import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/recipe.dart';

class GuideService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';
  static const String _systemPrompt = '''
You are a passionate Japanese ramen expert called The Master.
You run a small ramen counter restaurant in Japan. You speak directly to your head chef (the player).
You are warm, theatrical about ramen, and deeply knowledgeable about Japan's regional ramen varieties —
from Hakata tonkotsu to Sapporo miso, Kitakata shoyu, Wakayama chuka soba, and beyond.
Never break character. When asked to output JSON, output ONLY valid JSON with no markdown,
no backticks, no preamble whatsoever.''';

  static const String _jsonTrigger = '''
Generate the recipe now as JSON only.
No markdown, no backticks, no preamble. Raw JSON only matching this exact schema:
{
  "dish_name": "",
  "region": "",
  "prefecture": "",
  "rarity": "common|regional|rare|legendary",
  "flavor_tags": [],
  "teaser": "one dramatic sentence for discovery card",
  "long_description": "2-3 paragraph theatrical narrative about this dish — its history, flavors, and soul",
  "ingredients": [
    {"name": "", "amount": ""},
    {"name": "", "amount": ""},
    {"name": "", "amount": ""}
  ],
  "steps": [
    {"name": "step title", "description": "brief action", "seedance_prompt": "cinematic cooking video prompt for this step"},
    {"name": "step title", "description": "brief action", "seedance_prompt": "cinematic cooking video prompt for this step"},
    {"name": "step title", "description": "brief action", "seedance_prompt": "cinematic cooking video prompt for this step"}
  ],
  "serving_video_prompt": "cinematic video of the finished bowl being served on a restaurant counter",
  "tripo_prompt": "food photography for 3D generation, white background"
}
IMPORTANT: Exactly 3 ingredients. Exactly 3 steps. Each step must have a seedance_prompt describing a cinematic food video of that cooking action.
Use only these flavor tags: fermented|regional|fish|pork|rich|delicate|street_food|umami|pressed|smoky|crispy|rare|photogenic|comfort|seasonal''';

  static const List<String> _validTags = [
    'fermented', 'regional', 'fish', 'pork', 'rich', 'delicate',
    'street_food', 'umami', 'pressed', 'smoky', 'crispy', 'rare',
    'photogenic', 'comfort', 'seasonal',
  ];

  final List<Map<String, dynamic>> _messages = [];
  String? _base64Image;

  String get _apiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': _apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// Detect image MIME type from magic bytes
  String _detectMediaType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'image/webp';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'image/gif';
    }
    // Default to jpeg if unknown
    return 'image/jpeg';
  }

  /// Sends image as base64 + text prompt to Claude.
  /// Returns The Master's opening line about the dish.
  Future<String> identifyDish(Uint8List imageBytes) async {
    _base64Image = base64Encode(imageBytes);
    final mediaType = _detectMediaType(imageBytes);

    _messages.clear();
    _messages.add({
      'role': 'user',
      'content': [
        {
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': mediaType,
            'data': _base64Image,
          },
        },
        {
          'type': 'text',
          'text':
              'Look at this bowl of ramen. Tell me what style it is, what region of Japan it comes from, and what makes it special. Be theatrical and passionate — this is a discovery moment for your head chef.',
        },
      ],
    });

    final responseText = await _callClaude();

    _messages.add({
      'role': 'assistant',
      'content': responseText,
    });

    return responseText;
  }

  /// Appends player message to history, calls Claude, returns response.
  /// Used for one optional follow-up question.
  Future<String> chat(String playerMessage) async {
    _messages.add({
      'role': 'user',
      'content': playerMessage,
    });

    final responseText = await _callClaude();

    _messages.add({
      'role': 'assistant',
      'content': responseText,
    });

    return responseText;
  }

  /// Appends final trigger message asking for JSON only.
  /// Parses response into Recipe object.
  /// Falls back to Recipe.fixture() on any error.
  Future<Recipe> generateRecipe() async {
    _messages.add({
      'role': 'user',
      'content': _jsonTrigger,
    });

    final responseText = await _callClaude();

    _messages.add({
      'role': 'assistant',
      'content': responseText,
    });

    return _parseRecipe(responseText);
  }

  /// Clears conversation history and stored image. Call when starting a new dish.
  void reset() {
    _messages.clear();
    _base64Image = null;
  }

  Recipe _parseRecipe(String responseText) {
    try {
      final recipe = Recipe.fromJson(jsonDecode(responseText));
      return _filterTags(recipe);
    } catch (e) {
      // Try extracting JSON if Claude added any wrapper text
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (match != null) {
        try {
          final recipe = Recipe.fromJson(jsonDecode(match.group(0)!));
          return _filterTags(recipe);
        } catch (_) {}
      }
      return Recipe.fixture();
    }
  }

  /// Filter out any tags not in the locked vocabulary.
  Recipe _filterTags(Recipe recipe) {
    final filtered = recipe.flavorTags
        .where((tag) => _validTags.contains(tag))
        .toList();
    return Recipe(
      dishName: recipe.dishName,
      region: recipe.region,
      prefecture: recipe.prefecture,
      rarity: recipe.rarity,
      flavorTags: filtered,
      teaser: recipe.teaser,
      longDescription: recipe.longDescription,
      ingredients: recipe.ingredients,
      steps: recipe.steps,
      servingVideoPrompt: recipe.servingVideoPrompt,
      tripoPrompt: recipe.tripoPrompt,
    );
  }

  Future<String> _callClaude() async {
    // Use higher token limit for recipe generation (JSON is large)
    final isRecipeCall = _messages.isNotEmpty &&
        _messages.last['content'] is String &&
        (_messages.last['content'] as String).contains('Generate the recipe');
    final body = jsonEncode({
      'model': _model,
      'max_tokens': isRecipeCall ? 4096 : 1024,
      'system': _systemPrompt,
      'messages': _messages,
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('Claude API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    if (content.isEmpty) {
      throw Exception('Empty response from Claude');
    }
    return content[0]['text'] as String;
  }
}
