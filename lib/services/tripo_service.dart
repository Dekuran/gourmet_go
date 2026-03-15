import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
  /// Throws on failure status.
  Future<String?> pollResult(String taskId) async {
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
      throw Exception(
          'Tripo poll error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final status = data['data']?['status'] as String?;

    if (status == 'success') {
      // Try multiple response paths — Tripo uses pbr_model for textured GLB
      final output = data['data']?['output'];
      if (output != null) {
        final url = output['pbr_model'] ?? output['model'];
        if (url is String) return url;
      }
      // Also check nested result object
      final result = data['data']?['result'];
      if (result != null) {
        final pbrModel = result['pbr_model'];
        if (pbrModel is Map) return pbrModel['url'] as String?;
        if (pbrModel is String) return pbrModel;
      }
      return null;
    }

    if (status == 'failed') {
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
  }) {
    Future.microtask(() async {
      int attempts = 0;
      const maxAttempts = 20; // ~60 seconds max (20 x 3s)

      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
        attempts++;
        try {
          final url = await pollResult(taskId);
          if (url != null) {
            onComplete(url);
            return;
          }
        } catch (e) {
          if (e.toString().contains('failed')) {
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
    const maxAttempts = 20;

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(seconds: 3));
      attempts++;
      final url = await pollResult(taskId);
      if (url != null) return url;
    }
    throw Exception('Tripo: timed out after ${maxAttempts * 3} seconds');
  }
}
