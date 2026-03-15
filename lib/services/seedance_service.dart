import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// BytePlus ModelArk Seedance video generation service.
/// Uses the contents/generations/tasks async API with Seedance 1.5 Pro.
class SeedanceService {
  static const String _baseUrl =
      'https://ark.ap-southeast.bytepluses.com/api/v3';
  static const String _tasksEndpoint = '$_baseUrl/contents/generations/tasks';

  // Seedance 1.5 Pro — best quality available
  static const String _model = 'seedance-1-5-pro-251215';

  // No pre-baked local video assets — all videos are generated live via API

  String get _apiKey => dotenv.env['ARK_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  /// Main entry point for the game. Call this when an order completes.
  /// Returns a local asset path OR a remote mp4 URL.
  /// Never throws — always falls back to local asset.
  Future<String> triggerWowMoment({
    required String dishName,
    required List<String> ingredients,
    String style = 'cinematic',
  }) async {
    // Live generation via API
    try {
      final prompt = _buildPrompt(
        dishName: dishName,
        ingredients: ingredients,
        style: style,
      );
      final taskId = await startGeneration(prompt);
      return await _pollUntilDone(taskId);
    } catch (e) {
      print('SeedanceService error: $e');
      // No local fallback — propagate null so caller can handle gracefully
      return '';
    }
  }

  /// Creates a text-to-video generation task.
  /// Returns the task ID for polling.
  Future<String> startGeneration(String prompt) async {
    // Append default video params to prompt
    final fullPrompt = '$prompt --resolution 720p --duration 5 --ratio 16:9';

    final body = jsonEncode({
      'model': _model,
      'content': [
        {
          'type': 'text',
          'text': fullPrompt,
        },
      ],
    });

    final response = await http.post(
      Uri.parse(_tasksEndpoint),
      headers: _headers,
      body: body,
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
          'Seedance create task error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final taskId = data['id'] as String?;

    if (taskId == null) {
      throw Exception('No task id in Seedance response: ${response.body}');
    }

    return taskId;
  }

  /// Polls for task result.
  /// Returns video URL when status is 'succeeded', null if still processing.
  /// Throws on failure status.
  Future<String?> pollResult(String taskId) async {
    // Mock fallback — no local videos, return a placeholder URL
    if (taskId.startsWith('mock_')) {
      // Return null so caller knows mock has no real asset
      return null;
    }

    final response = await http.get(
      Uri.parse('$_tasksEndpoint/$taskId'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Seedance poll error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final status = (data['status'] as String? ?? '').toLowerCase();

    if (status == 'succeeded') {
      final videoUrl = _extractVideoUrl(data);
      if (videoUrl == null) {
        throw Exception('Seedance task succeeded but no video URL found');
      }
      return videoUrl;
    }

    if (status == 'failed' || status == 'cancelled') {
      final error = data['error'] ?? data['last_error'] ?? 'Unknown error';
      throw Exception('Seedance task $status: $error');
    }

    // Still processing (queued, running, etc.)
    return null;
  }

  /// Starts polling in the background and calls onComplete when ready.
  /// [onStatus] is called with intermediate status text for UI updates.
  void startPollingInBackground(
    String taskId,
    Function(String) onComplete, {
    Function(String)? onError,
    Function(String)? onStatus,
  }) {
    Future.microtask(() async {
      int attempts = 0;
      const maxAttempts = 60; // 5 minutes max (60 x 5s)

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 5));
        attempts++;
        onStatus?.call('Polling $taskId (${attempts * 5}s)...');
        try {
          final url = await pollResult(taskId);
          if (url != null) {
            onComplete(url);
            return;
          }
        } catch (e) {
          if (e.toString().contains('failed') ||
              e.toString().contains('cancelled')) {
            onError?.call(e.toString());
            return;
          }
          // Keep polling on transient errors
        }
      }
      onError?.call('Seedance: timed out after ${maxAttempts * 5} seconds');
    });
  }

  /// Response shape varies across API versions — check multiple paths.
  /// Actual response: { "content": { "video_url": "https://..." } }
  String? _extractVideoUrl(Map<String, dynamic> data) {
    final content = data['content'];

    // Path 1: content is a Map with video_url (actual Seedance 1.5 response)
    if (content is Map) {
      final url = content['video_url'] ?? content['url'];
      if (url is String) return url;
    }

    // Path 2: content is a List with video_url type items
    if (content is List && content.isNotEmpty) {
      for (final item in content) {
        if (item is Map) {
          // type: video_url with nested url
          if (item['type'] == 'video_url') {
            final videoUrl = item['video_url'];
            if (videoUrl is Map) return videoUrl['url'] as String?;
            if (videoUrl is String) return videoUrl;
          }
          // Direct url field
          final url = item['video_url'] ?? item['url'];
          if (url is String) return url;
        }
      }
    }

    // Path 3: top-level video object
    final video = data['video'];
    if (video is Map) {
      final url = video['url'];
      if (url is String) return url;
    }

    // Path 4: top-level output
    final output = data['output'];
    if (output is Map) {
      final url = output['video_url'] ?? output['url'];
      if (url is String) return url;
    }

    return null;
  }

  /// Polls until done (blocking). Used by triggerWowMoment.
  Future<String> _pollUntilDone(String taskId) async {
    int attempts = 0;
    const maxAttempts = 24;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 5));
      attempts++;
      final url = await pollResult(taskId);
      if (url != null) return url;
    }
    throw Exception('Seedance: timed out after ${maxAttempts * 5} seconds');
  }

  String _buildPrompt({
    required String dishName,
    required List<String> ingredients,
    required String style,
  }) {
    final ingredientList = ingredients.take(4).join(', ');

    if (style == 'ukiyoe') {
      return 'Japanese sous chef preparing $dishName, working with '
          '$ingredientList. Ukiyo-e woodblock print style, flat bold '
          'colours, dramatic composition, warm ink tones, traditional '
          'Japanese kitchen.';
    }

    return 'Japanese sous chef carefully preparing $dishName, '
        'working with $ingredientList, plating at a clean wooden counter. '
        'Cinematic food documentary, warm kitchen lighting, slow deliberate '
        'movements, close-up detail shots.';
  }
}
