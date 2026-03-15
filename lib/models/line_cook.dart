class LineCook {
  final String name;
  final List<String> specialtyRegions;
  final List<String> strengthTags;
  final List<String> weaknessTags;
  final String personality;
  final String backstory;

  LineCook({
    required this.name,
    required this.specialtyRegions,
    required this.strengthTags,
    required this.weaknessTags,
    required this.personality,
    required this.backstory,
  });

  factory LineCook.fromJson(Map<String, dynamic> json) => LineCook(
    name: json['name'] ?? 'Kenji',
    specialtyRegions: List<String>.from(json['specialty_regions'] ?? []),
    strengthTags: List<String>.from(json['strength_tags'] ?? []),
    weaknessTags: List<String>.from(json['weakness_tags'] ?? []),
    personality: json['personality'] ?? 'focused',
    backstory: json['backstory'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'specialty_regions': specialtyRegions,
    'strength_tags': strengthTags,
    'weakness_tags': weaknessTags,
    'personality': personality,
    'backstory': backstory,
  };

  static LineCook fixture() => LineCook.fromJson({
    "name": "Kenji",
    "specialty_regions": ["Kyushu", "Kansai"],
    "strength_tags": ["pork", "rich", "umami"],
    "weakness_tags": ["delicate", "fish"],
    "personality": "intense",
    "backstory":
        "Trained at a Hakata ramen yatai for 8 years. Stirs tonkotsu broth like his life depends on it."
  });
}
