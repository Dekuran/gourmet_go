import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/dish.dart';
import '../models/recipe.dart';
import 'debug_logger.dart';

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
    {"name": "step title", "description": "brief action", "seedance_prompt": "dreamy anime aesthetic cooking video prompt for this step, soft pastel colours, warm golden lighting, no speech, no words, no text, no dialogue, only ambient sound effects"},
    {"name": "step title", "description": "brief action", "seedance_prompt": "dreamy anime aesthetic cooking video prompt for this step, soft pastel colours, warm golden lighting, no speech, no words, no text, no dialogue, only ambient sound effects"},
    {"name": "step title", "description": "brief action", "seedance_prompt": "dreamy anime aesthetic cooking video prompt for this step, soft pastel colours, warm golden lighting, no speech, no words, no text, no dialogue, only ambient sound effects"}
  ],
  "serving_video_prompt": "dreamy anime aesthetic video of the finished bowl being served on a restaurant counter, soft pastel colours, warm golden lighting, no speech, no words, no text, no dialogue, only ambient sound effects",
  "tripo_prompt": "food photography for 3D generation, white background"
}
IMPORTANT: Exactly 3 ingredients. Exactly 3 steps. Each step must have a seedance_prompt describing a dreamy anime aesthetic food video of that cooking action with soft pastel colours and warm golden lighting. Videos must have NO speech, NO words, NO text, NO dialogue — only ambient sound effects.
Use only these flavor tags: fermented|regional|fish|pork|rich|delicate|street_food|umami|pressed|smoky|crispy|rare|photogenic|comfort|seasonal''';

  /// Prompt that asks Claude to return structured identification JSON
  /// matching the [Dish.fromIdentification] factory fields.
  ///
  /// Used by [identifyDishStructured] for the FTUE pipeline where
  /// we need `confidence_0_to_1` for branching logic (retry if < 0.6).
  static const String _structuredIdentifyTrigger = '''
Identify this dish and return ONLY valid JSON. No markdown, no backticks, no preamble.
Return a single JSON object matching this exact schema:
{
  "variety_id": "lowercase_snake_case id e.g. hakata_tonkotsu",
  "ramen_name": "display name e.g. Hakata Tonkotsu Ramen",
  "regional_style": "regional style e.g. Hakata-style",
  "broth_base": "one of: tonkotsu, shoyu, miso, shio, other",
  "rarity_tier": 1,
  "regional_lore": "1-2 sentences about where this dish comes from and what makes it special",
  "confidence_0_to_1": 0.92
}
Rules:
- variety_id: lowercase snake_case, region + style e.g. "sapporo_miso", "hakata_tonkotsu"
- rarity_tier: 1 (common everyday ramen), 2 (regional specialty), 3 (rare artisan), 4 (legendary)
- confidence_0_to_1: your honest confidence this is actually a Japanese ramen dish (0.0 to 1.0). If it's clearly ramen, ≥ 0.8. If uncertain or not ramen at all, < 0.5.
- broth_base: the primary broth type. Use "other" only if truly unclassifiable.
- regional_lore: speak as The Master — warm, theatrical, 1-2 sentences max.''';

  static const List<String> _validTags = [
    'fermented', 'regional', 'fish', 'pork', 'rich', 'delicate',
    'street_food', 'umami', 'pressed', 'smoky', 'crispy', 'rare',
    'photogenic', 'comfort', 'seasonal',
  ];

  static final _log = DebugLogger.instance;

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
  /// Returns The Master's opening line about the dish (theatrical prose).
  ///
  /// For structured data suitable for creating a [Dish], use
  /// [identifyDishStructured] instead.
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
              'Look at this bowl of ramen. In 2-3 short sentences, name the style, the region of Japan it comes from, and one thing that makes it special. Be warm and passionate but brief — this is a discovery moment.',
        },
      ],
    });

    final responseText = await _callClaude();

    _messages.add({
      'role': 'assistant',
      'content': responseText,
    });

    _log.logSuccess('GuideService', 'identifyDish', 'Prose response received (${responseText.length} chars)');

    return responseText;
  }

  /// Sends image to Claude and returns structured JSON for dish identification.
  ///
  /// The returned map matches the [Dish.fromIdentification] factory:
  /// ```json
  /// {
  ///   "variety_id": "hakata_tonkotsu",
  ///   "ramen_name": "Hakata Tonkotsu Ramen",
  ///   "regional_style": "Hakata-style",
  ///   "broth_base": "tonkotsu",
  ///   "rarity_tier": 2,
  ///   "regional_lore": "Born in the yatai stalls of Fukuoka...",
  ///   "confidence_0_to_1": 0.92
  /// }
  /// ```
  ///
  /// The `confidence_0_to_1` field drives FTUE branching:
  /// - `>= 0.6` → dish accepted, proceed to reveal
  /// - `< 0.6` → retry branch, offer starter bowls
  ///
  /// Throws on network error. Returns a low-confidence fallback map
  /// if Claude's response cannot be parsed as valid JSON.
  Future<Map<String, dynamic>> identifyDishStructured(
    Uint8List imageBytes,
  ) async {
    final base64Image = base64Encode(imageBytes);
    final mediaType = _detectMediaType(imageBytes);

    // Single-turn call — no conversation history needed.
    final messages = <Map<String, dynamic>>[
      {
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': mediaType,
              'data': base64Image,
            },
          },
          {
            'type': 'text',
            'text': _structuredIdentifyTrigger,
          },
        ],
      },
    ];

    final body = jsonEncode({
      'model': _model,
      'max_tokens': 512,
      'system': _systemPrompt,
      'messages': messages,
    });

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: _headers,
      body: body,
    );

    if (response.statusCode != 200) {
      _log.logError(
        'GuideService',
        'identifyDishStructured',
        'Claude API error ${response.statusCode}',
      );
      throw Exception(
        'Claude API error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final content = data['content'] as List;
    if (content.isEmpty) {
      _log.logError(
        'GuideService',
        'identifyDishStructured',
        'Empty response from Claude',
      );
      throw Exception('Empty response from Claude');
    }

    final responseText = content[0]['text'] as String;
    final parsed = _parseStructuredIdentification(responseText);

    final confidence = parsed['confidence_0_to_1'] as num? ?? 0.0;
    final name = parsed['ramen_name'] as String? ?? 'Unknown';
    _log.logSuccess(
      'GuideService',
      'identifyDishStructured',
      '$name (confidence: $confidence)',
    );

    return parsed;
  }

  /// Convenience wrapper that calls [identifyDishStructured] and returns
  /// a [Dish] instance via [Dish.fromIdentification].
  ///
  /// On any error, returns a fallback [Dish] with confidence 0.0.
  Future<Dish> identifyAsDish(Uint8List imageBytes) async {
    try {
      final json = await identifyDishStructured(imageBytes);
      return Dish.fromIdentification(json);
    } catch (e) {
      _log.logError('GuideService', 'identifyAsDish', '$e');
      return Dish(
        varietyId: 'unknown',
        name: 'Unknown Ramen',
        regionalStyle: '',
        brothBase: '',
        rarityTier: 1,
        confidence: 0.0,
      );
    }
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
    _log.logInfo('GuideService', 'Conversation reset');
  }

  /// Attempts to parse structured identification JSON from Claude's response.
  ///
  /// Falls back to a low-confidence placeholder if parsing fails.
  Map<String, dynamic> _parseStructuredIdentification(String responseText) {
    try {
      final parsed = jsonDecode(responseText) as Map<String, dynamic>;
      return _validateIdentification(parsed);
    } catch (_) {
      // Claude may have wrapped JSON in markdown or added preamble.
      final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(responseText);
      if (match != null) {
        try {
          final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
          return _validateIdentification(parsed);
        } catch (_) {}
      }
      _log.logError(
        'GuideService',
        '_parseStructuredIdentification',
        'Failed to parse: ${responseText.substring(0, responseText.length.clamp(0, 120))}',
      );
      // Return a low-confidence fallback so the FTUE can trigger retry branch.
      return <String, dynamic>{
        'variety_id': 'unknown',
        'ramen_name': 'Unknown Ramen',
        'regional_style': '',
        'broth_base': 'other',
        'rarity_tier': 1,
        'regional_lore': '',
        'confidence_0_to_1': 0.0,
      };
    }
  }

  /// Ensures required fields exist with sensible defaults.
  Map<String, dynamic> _validateIdentification(Map<String, dynamic> json) {
    return <String, dynamic>{
      'variety_id': json['variety_id'] as String? ?? 'unknown',
      'ramen_name': json['ramen_name'] as String? ?? 'Unknown Ramen',
      'regional_style': json['regional_style'] as String? ?? '',
      'broth_base': json['broth_base'] as String? ?? 'other',
      'rarity_tier': json['rarity_tier'] as int? ?? 1,
      'regional_lore': json['regional_lore'] as String? ?? '',
      'confidence_0_to_1':
          (json['confidence_0_to_1'] as num?)?.toDouble() ?? 0.0,
    };
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
