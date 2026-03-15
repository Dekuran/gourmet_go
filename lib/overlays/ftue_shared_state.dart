import 'dart:typed_data';

import '../models/dish.dart';

/// Shared ephemeral state passed between FTUE overlays.
///
/// The camera overlay writes here after identification;
/// the dish reveal overlay reads from here.
/// This avoids fragile static fields on private State classes.
class FtueSharedState {
  FtueSharedState._();
  static final FtueSharedState instance = FtueSharedState._();

  /// The most recently identified dish from the camera overlay.
  Dish? lastDish;

  /// The raw photo bytes used for identification.
  Uint8List? lastPhotoBytes;

  /// Clear ephemeral state (e.g. after FTUE completes).
  void clear() {
    lastDish = null;
    lastPhotoBytes = null;
  }
}
