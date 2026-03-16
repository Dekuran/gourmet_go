/// A discovered dish in the player's menu.
///
/// Created when the player photographs a bowl and the vision AI
/// successfully identifies it. Fields align with the API contract
/// from `GET /ramen/varieties` response structure and the
/// `GuideService.identifyDishStructured()` output.
///
/// See [restaurant_sim_prototype.md §8](../../docs/restaurant_sim_prototype.md)
/// and [flame_implementation.md §Data Models](../../docs/flame_implementation.md).
class Dish {
  Dish({
    required this.varietyId,
    required this.name,
    required this.regionalStyle,
    required this.brothBase,
    required this.rarityTier,
    this.price,
    this.playerPhotoPath,
    this.glbUrl,
    this.recipeVideoUrls = const [],
    this.recipeStepLabels = const [],
    this.recipeIngredients = const [],
    this.recipeSummary,
    this.regionalLore,
    this.confidence,
  });

  /// Unique ID matching the backend variety catalogue.
  final String varietyId;

  /// Display name, e.g. "Tonkotsu Ramen".
  final String name;

  /// Regional style, e.g. "Hakata-style".
  final String regionalStyle;

  /// Broth base type: tonkotsu, shoyu, miso, shio.
  final String brothBase;

  /// Rarity tier: 1 (common) – 4 (legendary).
  final int rarityTier;

  /// Price in yen, fetched from `GET /ramen/{variety_id}/price`.
  /// Null until the price API responds.
  final int? price;

  /// Local path to the player's photo of this dish.
  final String? playerPhotoPath;

  /// URL or local path to the 3D GLB model (from Tripo).
  /// Null until Tripo generation completes.
  final String? glbUrl;

  /// Generated recipe / serving video URLs for this dish.
  final List<String> recipeVideoUrls;

  /// Display labels matching [recipeVideoUrls].
  final List<String> recipeStepLabels;

  /// Ingredient names captured from the generated recipe.
  final List<String> recipeIngredients;

  /// Short generated recipe summary or teaser.
  final String? recipeSummary;

  /// Lore paragraph from the region where this dish originates.
  final String? regionalLore;

  /// Vision AI confidence score (0.0–1.0) from identification.
  final double? confidence;

  /// Create a [Dish] from the structured JSON returned by
  /// `GuideService.identifyDishStructured()`.
  factory Dish.fromIdentification(Map<String, dynamic> json) {
    return Dish(
      varietyId: json['variety_id'] as String? ?? '',
      name: json['ramen_name'] as String? ?? 'Unknown Ramen',
      regionalStyle: json['regional_style'] as String? ?? '',
      brothBase: json['broth_base'] as String? ?? '',
      rarityTier: json['rarity_tier'] as int? ?? 1,
      regionalLore: json['regional_lore'] as String?,
      confidence: (json['confidence_0_to_1'] as num?)?.toDouble(),
    );
  }

  /// Create a [Dish] from the backend variety catalogue response.
  factory Dish.fromVariety(Map<String, dynamic> json) {
    return Dish(
      varietyId: json['variety_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      regionalStyle: json['regional_style'] as String? ?? '',
      brothBase: json['broth_base'] as String? ?? '',
      rarityTier: json['rarity_tier'] as int? ?? 1,
      price: json['price'] as int?,
      regionalLore: json['regional_lore'] as String?,
    );
  }

  /// Returns a copy with the given fields replaced.
  Dish copyWith({
    String? varietyId,
    String? name,
    String? regionalStyle,
    String? brothBase,
    int? rarityTier,
    int? price,
    String? playerPhotoPath,
    String? glbUrl,
    List<String>? recipeVideoUrls,
    List<String>? recipeStepLabels,
    List<String>? recipeIngredients,
    String? recipeSummary,
    String? regionalLore,
    double? confidence,
  }) {
    return Dish(
      varietyId: varietyId ?? this.varietyId,
      name: name ?? this.name,
      regionalStyle: regionalStyle ?? this.regionalStyle,
      brothBase: brothBase ?? this.brothBase,
      rarityTier: rarityTier ?? this.rarityTier,
      price: price ?? this.price,
      playerPhotoPath: playerPhotoPath ?? this.playerPhotoPath,
      glbUrl: glbUrl ?? this.glbUrl,
      recipeVideoUrls: recipeVideoUrls ?? this.recipeVideoUrls,
      recipeStepLabels: recipeStepLabels ?? this.recipeStepLabels,
      recipeIngredients: recipeIngredients ?? this.recipeIngredients,
      recipeSummary: recipeSummary ?? this.recipeSummary,
      regionalLore: regionalLore ?? this.regionalLore,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  String toString() => 'Dish($name, $regionalStyle, tier=$rarityTier)';
}
