/// A dish on the player's menu, identified via camera + GuideService.
///
/// Fields mirror the API contract from the ramen varieties endpoint.
class Dish {
  final String varietyId;
  final String name;
  final String regionalStyle;
  final String brothBase;
  final String rarityTier;
  final int price;
  final String? playerPhotoPath;
  final String regionalLore;

  const Dish({
    required this.varietyId,
    required this.name,
    required this.regionalStyle,
    required this.brothBase,
    this.rarityTier = 'common',
    this.price = 100,
    this.playerPhotoPath,
    this.regionalLore = '',
  });

  Dish copyWith({
    String? varietyId,
    String? name,
    String? regionalStyle,
    String? brothBase,
    String? rarityTier,
    int? price,
    String? playerPhotoPath,
    String? regionalLore,
  }) =>
      Dish(
        varietyId: varietyId ?? this.varietyId,
        name: name ?? this.name,
        regionalStyle: regionalStyle ?? this.regionalStyle,
        brothBase: brothBase ?? this.brothBase,
        rarityTier: rarityTier ?? this.rarityTier,
        price: price ?? this.price,
        playerPhotoPath: playerPhotoPath ?? this.playerPhotoPath,
        regionalLore: regionalLore ?? this.regionalLore,
      );

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        varietyId: json['variety_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        regionalStyle: json['regional_style'] as String? ?? '',
        brothBase: json['broth_base'] as String? ?? '',
        rarityTier: json['rarity_tier'] as String? ?? 'common',
        price: json['price'] as int? ?? 100,
        playerPhotoPath: json['player_photo_path'] as String?,
        regionalLore: json['regional_lore'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'variety_id': varietyId,
        'name': name,
        'regional_style': regionalStyle,
        'broth_base': brothBase,
        'rarity_tier': rarityTier,
        'price': price,
        'player_photo_path': playerPhotoPath,
        'regional_lore': regionalLore,
      };

  /// Pre-seeded starter bowls for fallback when camera fails.
  static const List<Dish> starterBowls = [
    Dish(
      varietyId: 'tonkotsu_001',
      name: 'Hakata Tonkotsu',
      regionalStyle: 'Kyushu',
      brothBase: 'pork bone',
      rarityTier: 'common',
      price: 120,
      regionalLore: 'Creamy pork bone broth simmered for hours.',
    ),
    Dish(
      varietyId: 'shoyu_001',
      name: 'Tokyo Shoyu',
      regionalStyle: 'Kanto',
      brothBase: 'soy sauce',
      rarityTier: 'common',
      price: 100,
      regionalLore: 'Crystal-clear soy broth, the refined classic.',
    ),
    Dish(
      varietyId: 'miso_001',
      name: 'Sapporo Miso',
      regionalStyle: 'Hokkaido',
      brothBase: 'miso',
      rarityTier: 'common',
      price: 110,
      regionalLore: 'Rich amber miso with corn and melting butter.',
    ),
  ];
}
