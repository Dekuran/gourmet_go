import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';

import 'debug_logger.dart';

/// How the player provides a ramen photo.
///
/// [camera] opens the device camera (iOS only for hackathon).
/// [gallery] opens the system file/photo picker.
/// [demo] loads the bundled default image — no user interaction needed.
enum PhotoMode {
  /// Device camera (requires permission).
  camera,

  /// System photo picker / file upload.
  gallery,

  /// Bundled demo image — instant, no permissions needed.
  /// Uses [PhotoSourceService.demoBowlAssetPath].
  demo,
}

/// Abstracts photo acquisition for the camera overlay.
///
/// In demo mode, returns the bundled tonkotsu ramen image so the
/// full FTUE flow can be shown without a physical camera or user
/// interaction with the file picker.
///
/// Usage in the camera overlay:
/// ```dart
/// final bytes = await PhotoSourceService.instance.acquirePhoto(PhotoMode.demo);
/// if (bytes != null) {
///   final dish = await guideService.identifyAsDish(bytes);
///   // ... proceed with dish reveal
/// }
/// ```
///
/// See [ftue_implementation_plan.md §3B](../../docs/ftue_implementation_plan.md).
class PhotoSourceService {
  PhotoSourceService._();
  static final PhotoSourceService instance = PhotoSourceService._();

  static final _log = DebugLogger.instance;

  final _picker = ImagePicker();

  /// Asset path to the bundled demo bowl image.
  ///
  /// This is the same tonkotsu ramen photo used in the API test screen.
  /// Loaded via Flutter's [rootBundle] in demo mode.
  static const demoBowlAssetPath = 'assets/images/tonkotsu_ramen_basic.png';

  /// Cached demo image bytes — loaded once, reused.
  Uint8List? _demoBowlCache;

  /// Acquire a photo using the specified [mode].
  ///
  /// Returns the raw image bytes, or `null` if the user cancelled
  /// (camera/gallery modes only — demo mode never returns null).
  ///
  /// The [imageQuality] parameter applies to camera and gallery modes
  /// only (0–100, where 100 is original quality).
  Future<Uint8List?> acquirePhoto(
    PhotoMode mode, {
    int imageQuality = 85,
  }) async {
    switch (mode) {
      case PhotoMode.camera:
        return _fromCamera(imageQuality: imageQuality);
      case PhotoMode.gallery:
        return _fromGallery(imageQuality: imageQuality);
      case PhotoMode.demo:
        return _fromDemoAsset();
    }
  }

  /// Load the bundled demo bowl image from assets.
  ///
  /// Cached after first load — subsequent calls return instantly.
  /// This is the recommended mode for hackathon demos and testing.
  Future<Uint8List> loadDemoBowl() async {
    if (_demoBowlCache != null) return _demoBowlCache!;

    final data = await rootBundle.load(demoBowlAssetPath);
    _demoBowlCache = data.buffer.asUint8List();
    _log.logSuccess(
      'PhotoSource',
      'loadDemoBowl',
      '${_demoBowlCache!.length} bytes from $demoBowlAssetPath',
    );
    return _demoBowlCache!;
  }

  /// Clear the demo image cache (if needed after hot restart).
  void clearCache() {
    _demoBowlCache = null;
  }

  // ── Private acquisition methods ──────────────────────────────────────────

  Future<Uint8List?> _fromCamera({required int imageQuality}) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: imageQuality,
      );
      if (xFile == null) {
        _log.logInfo('PhotoSource', 'Camera cancelled by user');
        return null;
      }
      final bytes = await xFile.readAsBytes();
      _log.logSuccess(
        'PhotoSource',
        'camera',
        '${bytes.length} bytes captured',
      );
      return bytes;
    } catch (e) {
      _log.logError('PhotoSource', 'camera', '$e');
      return null;
    }
  }

  Future<Uint8List?> _fromGallery({required int imageQuality}) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: imageQuality,
      );
      if (xFile == null) {
        _log.logInfo('PhotoSource', 'Gallery cancelled by user');
        return null;
      }
      final bytes = await xFile.readAsBytes();
      _log.logSuccess(
        'PhotoSource',
        'gallery',
        '${bytes.length} bytes picked',
      );
      return bytes;
    } catch (e) {
      _log.logError('PhotoSource', 'gallery', '$e');
      return null;
    }
  }

  Future<Uint8List> _fromDemoAsset() async {
    final bytes = await loadDemoBowl();
    _log.logInfo('PhotoSource', 'Demo mode — using bundled tonkotsu ramen');
    return bytes;
  }
}
