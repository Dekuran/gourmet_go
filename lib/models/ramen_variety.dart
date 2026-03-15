/// Mirrors the API response from GET /ramen/varieties.
class RamenVariety {
  final String varietyId;
  final String name;
  final String regionalStyle;
  final String brothBase;
  final String rarityTier;

  const RamenVariety({
    required this.varietyId,
    required this.name,
    required this.regionalStyle,
    required this.brothBase,
    this.rarityTier = 'common',
  });

  factory RamenVariety.fromJson(Map<String, dynamic> json) => RamenVariety(
        varietyId: json['variety_id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        regionalStyle: json['regional_style'] as String? ?? '',
        brothBase: json['broth_base'] as String? ?? '',
        rarityTier: json['rarity_tier'] as String? ?? 'common',
      );

  Map<String, dynamic> toJson() => {
        'variety_id': varietyId,
        'name': name,
        'regional_style': regionalStyle,
        'broth_base': brothBase,
        'rarity_tier': rarityTier,
      };
}
