import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/customer.dart';
import '../../models/recipe.dart';

class CustomerService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';

  static const List<String> _validTags = [
    'fermented', 'regional', 'fish', 'pork', 'rich', 'delicate',
    'street_food', 'umami', 'pressed', 'smoky', 'crispy', 'rare',
    'photogenic', 'comfort', 'seasonal',
  ];

  String get _apiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'x-api-key': _apiKey,
    'anthropic-version': '2023-06-01',
  };

  /// Generates 3 customers whose desires create interesting tension
  /// with the current menu.
  /// Falls back to Customer.fixtures() on any error.
  Future<List<Customer>> generateQueue(List<Recipe> currentMenu) async {
    try {
      final menuSummary = currentMenu
          .map((r) => '${r.dishName} (${r.flavorTags.join(', ')})')
          .join('; ');

      final prompt = '''Current menu: $menuSummary
Generate 3 customers as a JSON array. Some should match the menu well, one should want something the menu doesn't fully satisfy.
Each: name, type (foodie|tourist|adventurous|comfort), desires (2-3 tags), budget (high|medium|low).
Tags only from: fermented|regional|fish|pork|rich|delicate|street_food|umami|pressed|smoky|crispy|rare|photogenic|comfort|seasonal
Return ONLY valid JSON array.''';

      final body = jsonEncode({
        'model': _model,
        'max_tokens': 512,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: _headers,
        body: body,
      );

      if (response.statusCode != 200) {
        return Customer.fixtures();
      }

      final data = jsonDecode(response.body);
      final content = data['content'] as List;
      if (content.isEmpty) return Customer.fixtures();

      final responseText = content[0]['text'] as String;
      return _parseCustomers(responseText);
    } catch (e) {
      return Customer.fixtures();
    }
  }

  List<Customer> _parseCustomers(String responseText) {
    try {
      final list = jsonDecode(responseText) as List;
      return list
          .map((c) => Customer.fromJson(c as Map<String, dynamic>))
          .map(_filterTags)
          .toList();
    } catch (e) {
      // Try extracting JSON array if Claude added wrapper text
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(responseText);
      if (match != null) {
        try {
          final list = jsonDecode(match.group(0)!) as List;
          return list
              .map((c) => Customer.fromJson(c as Map<String, dynamic>))
              .map(_filterTags)
              .toList();
        } catch (_) {}
      }
      return Customer.fixtures();
    }
  }

  Customer _filterTags(Customer customer) {
    return Customer(
      name: customer.name,
      type: customer.type,
      desires:
          customer.desires.where((t) => _validTags.contains(t)).toList(),
      budget: customer.budget,
    );
  }
}
