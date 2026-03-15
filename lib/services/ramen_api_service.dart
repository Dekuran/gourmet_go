import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/dish.dart';
import 'debug_logger.dart';

/// Fixture-backed ramen variety & pricing API.
///
/// For the hackathon prototype this reads from local JSON fixtures
/// rather than hitting a real backend. The interface matches the
/// planned API contract from `restaurant_sim_prototype.md §8`:
///
/// - `GET /ramen/varieties`        → [getVarieties]
/// - `GET /ramen/{id}/price`       → [getPrice]
/// - `GET /ramen/varieties/{id}`   → [getVariety]
///
/// Fixtures live in `lib/fixtures/*.json`.
class RamenApiService {
  RamenApiService._();
  static final RamenApiService instance = RamenApiService._();

  static final _log = DebugLogger.instance;

  List<Dish>? _varietiesCache;

  /// Load all ramen varieties from fixtures.
  ///
  /// Merges data from ramen.json, takoyaki.json, and masuzushi.json
  /// plus the four starter bowls (one per region).
  Future<List<Dish>> getVarieties() async {
    if (_varietiesCache != null) return _varietiesCache!;

    final dishes = <Dish>[];

    // Load starter bowls — one per region
    for (final entry in _starterBowls) {
      dishes.add(Dish.fromVariety(entry));
    }

    // Load fixture files
    for (final path in _fixturePaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        // Each fixture has a top-level variety_id and name
        dishes.add(Dish.fromVariety(json));
      } catch (e) {
        _log.logError('RamenApi', 'getVarieties', '$path: $e');
      }
    }

    _varietiesCache = dishes;
    _log.logSuccess(
      'RamenApi',
      'getVarieties',
      '${dishes.length} varieties loaded',
    );
    return dishes;
  }

  /// Get a specific variety by ID.
  Future<Dish?> getVariety(String varietyId) async {
    final all = await getVarieties();
    try {
      return all.firstWhere((d) => d.varietyId == varietyId);
    } catch (_) {
      return null;
    }
  }

  /// Get the price for a variety. Returns a fixture-based price
  /// derived from rarity tier.
  ///
  /// Pricing formula: `basePrice + (rarityTier - 1) * 200`
  Future<int> getPrice(String varietyId) async {
    final dish = await getVariety(varietyId);
    if (dish == null) return 800; // default fallback
    return _priceForTier(dish.rarityTier);
  }

  /// Match a dish name to the closest variety in our catalogue.
  ///
  /// Used after GuideService identification to link the AI result
  /// to a known variety with pricing data.
  Future<Dish?> matchDish(String name, String brothBase) async {
    final all = await getVarieties();
    // Try exact broth match first
    final byBroth = all.where(
      (d) => d.brothBase.toLowerCase() == brothBase.toLowerCase(),
    );
    if (byBroth.isNotEmpty) return byBroth.first;
    // Fallback: any dish
    return all.isNotEmpty ? all.first : null;
  }

  int _priceForTier(int tier) => switch (tier) {
        1 => 800,
        2 => 1200,
        3 => 1800,
        4 => 2500,
        _ => 800,
      };

  static const _fixturePaths = [
    'lib/fixtures/ramen.json',
    'lib/fixtures/takoyaki.json',
    'lib/fixtures/masuzushi.json',
  ];

  /// Pre-seeded starter bowls — one per region, all common tier.
  static const _starterBowls = [
    {
      'variety_id': 'tonkotsu_hakata',
      'name': 'Hakata Tonkotsu Ramen',
      'regional_style': 'Hakata-style',
      'broth_base': 'tonkotsu',
      'rarity_tier': 1,
      'price': 800,
      'regional_lore':
          'Born in the bustling yatai stalls of Fukuoka, Hakata tonkotsu is the '
              'soul of Kyushu — creamy pork bone broth simmered for 12+ hours until '
              'it turns milky white. The thin straight noodles are served firm (kata) '
              'with chashu, pickled ginger, and sesame seeds.',
    },
    {
      'variety_id': 'shoyu_tokyo',
      'name': 'Tokyo Shoyu Ramen',
      'regional_style': 'Tokyo-style',
      'broth_base': 'shoyu',
      'rarity_tier': 1,
      'price': 800,
      'regional_lore':
          'The original ramen of Japan — Tokyo shoyu dates back to the early 1900s. '
              'A clear, deep-amber soy sauce broth with chicken and dashi base. '
              'Served with thin noodles, nori, bamboo shoots, and a perfect soft-boiled egg.',
    },
    {
      'variety_id': 'miso_sapporo',
      'name': 'Sapporo Miso Ramen',
      'regional_style': 'Sapporo-style',
      'broth_base': 'miso',
      'rarity_tier': 1,
      'price': 800,
      'regional_lore':
          'Created in 1955 in snowy Sapporo, miso ramen was designed to warm '
              'the soul through Hokkaido winters. Rich fermented soybean broth with '
              'sweet corn, butter, bean sprouts, and thick curly noodles.',
    },
    {
      'variety_id': 'shio_hakodate',
      'name': 'Hakodate Shio Ramen',
      'regional_style': 'Hakodate-style',
      'broth_base': 'shio',
      'rarity_tier': 1,
      'price': 800,
      'regional_lore':
          'The oldest style of ramen in Japan, Hakodate shio is pure elegance. '
              'A crystal-clear salt-based broth that lets every ingredient shine — '
              'thin noodles, delicate chicken, and a whisper of yuzu.',
    },
  ];
}
