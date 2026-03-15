class Customer {
  final String name;
  final String type; // foodie | tourist | adventurous | comfort
  final List<String> desires;
  final String budget; // high | medium | low

  Customer({
    required this.name,
    required this.type,
    required this.desires,
    required this.budget,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    name: json['name'] ?? 'Guest',
    type: json['type'] ?? 'tourist',
    desires: List<String>.from(json['desires'] ?? []),
    budget: json['budget'] ?? 'medium',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'desires': desires,
    'budget': budget,
  };

  static List<Customer> fixtures() => [
    Customer(
      name: 'Yuki',
      type: 'foodie',
      desires: ['rich', 'pork', 'regional'],
      budget: 'high',
    ),
    Customer(
      name: 'Marco',
      type: 'tourist',
      desires: ['umami', 'comfort'],
      budget: 'medium',
    ),
    Customer(
      name: 'Aiko',
      type: 'adventurous',
      desires: ['smoky', 'rare'],
      budget: 'high',
    ),
  ];
}
