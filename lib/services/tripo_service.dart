import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'debug_logger.dart';

/// Tripo3D image-to-3D-model generation service.
/// Two-step flow: upload image → get token → create task → poll for GLB URL.
class TripoService {
  static const String _baseUrl = 'https://api.tripo3d.ai/v2/openapi';

  String get _apiKey => dotenv.env['TRIPO_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  /// Full pipeline: upload image → start generation → poll → return GLB url.
  /// This is the game entry point — fire immediately when food photo is taken.
  /// Never throws — falls back to local asset on failure.
  Future<String> generateFromImage(Uint8List imageBytes) async {
    try {
      final taskId = await startGeneration(imageBytes);
      return await _pollUntilDone(taskId);
    } catch (e) {
      print('TripoService error: $e');
      return 'assets/models/tonkotsu_ramen.glb'; // Safe fallback — real GLB
    }
  }

  /// Uploads image and starts 3D model generation.
  /// Returns task ID for polling.
  Future<String> startGeneration(Uint8List imageBytes) async {
    // Step 1: Upload the image to get an image_token
    final uploadUri = Uri.parse('$_baseUrl/upload/sts');
    final uploadRequest = http.MultipartRequest('POST', uploadUri);
    uploadRequest.headers['Authorization'] = 'Bearer $_apiKey';
    uploadRequest.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: 'food_photo.jpeg',
      ),
    );

    final uploadStreamResponse = await uploadRequest.send();
    final uploadResponse =
        await http.Response.fromStream(uploadStreamResponse);

    if (uploadResponse.statusCode != 200) {
      throw Exception(
          'Tripo upload error ${uploadResponse.statusCode}: ${uploadResponse.body}');
    }

    final uploadData = jsonDecode(uploadResponse.body);
    final fileToken = uploadData['data']?['image_token'] as String?;

    if (fileToken == null) {
      throw Exception('No image_token in Tripo upload response');
    }

    // Step 2: Create the image-to-model task
    final taskBody = jsonEncode({
      'type': 'image_to_model',
      'file': {
        'type': 'jpeg',
        'file_token': fileToken,
      },
    });

    final taskResponse = await http.post(
      Uri.parse('$_baseUrl/task'),
      headers: _headers,
      body: taskBody,
    );

    if (taskResponse.statusCode != 200) {
      throw Exception(
          'Tripo task error ${taskResponse.statusCode}: ${taskResponse.body}');
    }

    final taskData = jsonDecode(taskResponse.body);
    final taskId = taskData['data']?['task_id'] as String?;

    if (taskId == null) {
      throw Exception('No task_id in Tripo task response');
    }

    return taskId;
  }

  /// Polls for task result.
  /// Returns GLB URL when status == 'success', null if still processing.
  /// Throws on failure status or if success but no URL found.
  Future<String?> pollResult(String taskId) async {
    final log = DebugLogger.instance;

    // Mock fallback — always use our real tonkotsu GLB
    if (taskId.startsWith('mock_')) {
      return 'assets/models/tonkotsu_ramen.glb';
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/task/$taskId'),
      headers: {
        'Authorization': 'Bearer $_apiKey',
      },
    );

    if (response.statusCode != 200) {
      log.logError('TripoService', 'pollResult', 'HTTP ${response.statusCode}: ${response.body}');
      throw Exception(
          'Tripo poll error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final status = data['data']?['status'] as String?;
    final progress = data['data']?['progress'];

    log.logInfo('TripoService', 'poll $taskId → status=$status progress=$progress');

    if (status == 'success') {
      // Log the full output structure so we can debug URL extraction
      log.logInfo('TripoService', 'SUCCESS response data keys: ${data['data']?.keys?.toList()}');
      final output = data['data']?['output'];
      if (output != null) {
        log.logInfo('TripoService', 'output keys: ${output is Map ? output.keys.toList() : output.runtimeType}');
        final url = output['pbr_model'] ?? output['model'] ?? output['base_model'];
        if (url is String) {
          log.logSuccess('TripoService', 'pollResult', 'GLB URL: $url');
          return url;
        }
      }
      // Also check nested result object
      final result = data['data']?['result'];
      if (result != null) {
        log.logInfo('TripoService', 'result keys: ${result is Map ? result.keys.toList() : result.runtimeType}');
        final pbrModel = result['pbr_model'];
        if (pbrModel is Map) {
          final url = pbrModel['url'] as String?;
          if (url != null) {
            log.logSuccess('TripoService', 'pollResult', 'GLB URL (nested): $url');
            return url;
          }
        }
        if (pbrModel is String) {
          log.logSuccess('TripoService', 'pollResult', 'GLB URL (string): $pbrModel');
          return pbrModel;
        }
      }
      // Success but couldn't extract URL — dump full response for debugging
      final bodySnippet = response.body.length > 500
          ? response.body.substring(0, 500)
          : response.body;
      log.logError('TripoService', 'pollResult',
          'Status=success but no GLB URL found. Response: $bodySnippet');
      throw Exception(
          'Tripo: task succeeded but could not extract GLB URL from response');
    }

    if (status == 'failed') {
      log.logError('TripoService', 'pollResult', 'Task $taskId failed');
      throw Exception('Tripo generation failed');
    }

    // Still processing (queued, running)
    return null;
  }

  /// Starts polling in the background and calls onComplete when the GLB URL is ready.
  void startPollingInBackground(
    String taskId,
    Function(String) onComplete, {
    Function(String)? onError,
    Function(String)? onStatus,
  }) {
    Future.microtask(() async {
      int attempts = 0;
      const maxAttempts = 40; // ~120 seconds max (40 x 3s)

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;
        try {
          // First do a raw poll to get progress for the status callback
          final response = await http.get(
            Uri.parse('$_baseUrl/task/$taskId'),
            headers: {'Authorization': 'Bearer $_apiKey'},
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final progress = data['data']?['progress'];
            final status = data['data']?['status'] as String?;
            if (progress != null && status != null) {
              onStatus?.call('$status — $progress%');
            }
          }

          final url = await pollResult(taskId);
          if (url != null) {
            onComplete(url);
            return;
          }
        } catch (e) {
          if (e.toString().contains('failed') || e.toString().contains('could not extract')) {
            onError?.call(e.toString());
            return;
          }
          // Keep polling on transient errors
        }
      }
      onError?.call('Tripo: timed out after ${maxAttempts * 3} seconds');
    });
  }

  /// Polls until done (blocking). Used by generateFromImage.
  Future<String> _pollUntilDone(String taskId) async {
    int attempts = 0;
    const maxAttempts = 40;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 3));
      attempts++;
      final url = await pollResult(taskId);
      if (url != null) return url;
    }
    throw Exception('Tripo: timed out after ${maxAttempts * 3} seconds');
  }
}
