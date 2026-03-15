import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/region.dart';

/// Tracks which regions are unlocked.
///
/// Regions unlock when a dish from that region is photographed
/// and added to the menu. Kanto is unlocked by default (home).
class RegionNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {
        for (final r in Region.all) r.id: r.id == 'kanto',
      };

  void unlock(String regionId) {
    state = {...state, regionId: true};
  }

  bool isUnlocked(String regionId) => state[regionId] ?? false;

  /// Unlock region matching a dish's regional style.
  void unlockByStyle(String regionalStyle) {
    for (final region in Region.all) {
      if (region.name.toLowerCase() == regionalStyle.toLowerCase() ||
          region.prefecture.toLowerCase() ==
              regionalStyle.toLowerCase()) {
        unlock(region.id);
        return;
      }
    }
  }
}

final regionProvider =
    NotifierProvider<RegionNotifier, Map<String, bool>>(
  RegionNotifier.new,
);
