/// A single preparation step in a ramen recipe.
/// Each step has a name, brief description, and a Seedance video prompt
/// that can be sent to the BytePlus API to generate a cooking video.
class PrepStep {
  final String name;
  final String description;
  final String seedancePrompt;

  PrepStep({
    required this.name,
    required this.description,
    required this.seedancePrompt,
  });

  factory PrepStep.fromJson(Map<String, dynamic> json) => PrepStep(
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    seedancePrompt: json['seedance_prompt'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'seedance_prompt': seedancePrompt,
  };
}
