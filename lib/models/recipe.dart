import 'prep_step.dart';

class Recipe {
  final String dishName;
  final String region;
  final String prefecture;
  final String rarity; // common | regional | rare | legendary
  final List<String> flavorTags;

  /// Short teaser shown in discovery / card view.
  final String teaser;

  /// Full theatrical narrative from The Master — shown in menu detail view.
  final String longDescription;

  /// Exactly 3 key ingredients (for Gemini image generation + gameplay).
  final List<Ingredient> ingredients;

  /// Exactly 3 preparation steps, each with its own Seedance video prompt.
  final List<PrepStep> steps;

  /// Seedance prompt for the final "serving on the counter" video.
  final String servingVideoPrompt;

  /// Tripo 3D model prompt.
  final String tripoPrompt;

  Recipe({
    required this.dishName,
    required this.region,
    required this.prefecture,
    required this.rarity,
    required this.flavorTags,
    required this.teaser,
    required this.longDescription,
    required this.ingredients,
    required this.steps,
    required this.servingVideoPrompt,
    required this.tripoPrompt,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    dishName: json['dish_name'] ?? '',
    region: json['region'] ?? '',
    prefecture: json['prefecture'] ?? '',
    rarity: json['rarity'] ?? 'common',
    flavorTags: List<String>.from(json['flavor_tags'] ?? []),
    teaser: json['teaser'] ?? '',
    longDescription: json['long_description'] ?? json['description'] ?? '',
    ingredients: (json['ingredients'] as List? ?? [])
        .map((i) => Ingredient.fromJson(i))
        .toList(),
    steps: (json['steps'] as List? ?? [])
        .map((s) => PrepStep.fromJson(s))
        .toList(),
    servingVideoPrompt: json['serving_video_prompt'] ?? '',
    tripoPrompt: json['tripo_prompt'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'dish_name': dishName,
    'region': region,
    'prefecture': prefecture,
    'rarity': rarity,
    'flavor_tags': flavorTags,
    'teaser': teaser,
    'long_description': longDescription,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'serving_video_prompt': servingVideoPrompt,
    'tripo_prompt': tripoPrompt,
  };

  /// Convenience: names of all ingredients.
  List<String> get ingredientNames =>
      ingredients.map((i) => i.name).toList();

  static Recipe fixture() => Recipe.fromJson({
    "dish_name": "Hakata Tonkotsu Ramen",
    "region": "Kyushu",
    "prefecture": "Fukuoka",
    "rarity": "regional",
    "flavor_tags": ["pork", "rich", "umami", "comfort"],
    "teaser":
        "There is a bowl here that takes half a day of boiling bones to make. The broth is not soup — it is liquid silk.",
    "long_description":
        "Ah, my dear chef — behold the crown jewel of Fukuoka! Hakata Tonkotsu Ramen is born from "
        "patience itself. Pork bones simmer for twelve, sometimes eighteen hours until the collagen "
        "surrenders into a milky, creamy broth that coats your soul. The thin, straight noodles are "
        "firm — kata-men — because in Hakata, we respect the bite. Slices of melt-in-your-mouth "
        "chashu pork drape across the bowl like silk. A soft-boiled ajitama egg, its yolk still "
        "flowing like sunset gold. And do not forget the beni shoga — that sharp pickled ginger "
        "that cuts through the richness like a samurai's blade. This is not just ramen. This is "
        "Fukuoka's gift to the world.",
    "ingredients": [
      {"name": "pork bone broth", "amount": "400ml"},
      {"name": "chashu pork belly", "amount": "3 slices"},
      {"name": "ajitama egg", "amount": "1 half"},
    ],
    "steps": [
      {
        "name": "Simmer the broth",
        "description": "Boil pork bones on high heat for 12 hours until milky white.",
        "seedance_prompt":
            "Close-up of a large pot of milky white tonkotsu pork bone broth boiling vigorously on a gas stove in a traditional Japanese ramen kitchen, steam rising, warm lighting, cinematic food documentary style"
      },
      {
        "name": "Prepare the toppings",
        "description": "Slice chashu pork and halve the soft-boiled ajitama egg.",
        "seedance_prompt":
            "Japanese chef's hands slicing braised chashu pork belly into perfect rounds on a wooden cutting board, then halving a soft-boiled ajitama egg revealing golden yolk, traditional ramen kitchen, cinematic food documentary style"
      },
      {
        "name": "Assemble the bowl",
        "description": "Cook thin noodles kata-men, ladle broth, arrange toppings artfully.",
        "seedance_prompt":
            "Japanese chef assembling a bowl of Hakata tonkotsu ramen — placing thin firm noodles in a round ceramic bowl, ladling milky white broth, carefully arranging chashu slices and halved egg, traditional ramen counter, cinematic food documentary style"
      },
    ],
    "serving_video_prompt":
        "A steaming bowl of Hakata tonkotsu ramen being placed on a wooden counter of a cozy Japanese ramen restaurant, steam rising beautifully, warm ambient lighting, the chef's hands sliding the bowl forward, cinematic food documentary style",
    "tripo_prompt":
        "Hakata tonkotsu ramen in a round ceramic bowl with milky white broth, thin noodles, sliced chashu pork, soft-boiled egg, Japanese food, top-down view, white background",
  });
}

class Ingredient {
  final String name;
  final String amount;

  Ingredient({required this.name, required this.amount});

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    name: json['name'] ?? '',
    amount: json['amount'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'amount': amount,
  };
}
