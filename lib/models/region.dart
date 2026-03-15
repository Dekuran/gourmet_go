import 'package:flutter/material.dart';

class Region {
  final String id;
  final String name;
  final String prefecture;
  final String ramenType;
  final String ramenEmoji;
  final String ramenDescription;
  /// Normalized 0-1 position on the map canvas
  final Offset mapPosition;
  final Color primaryColor;
  final Color secondaryColor;
  final List<String> connectedTo;
  final String arrivalQuote;

  const Region({
    required this.id,
    required this.name,
    required this.prefecture,
    required this.ramenType,
    required this.ramenEmoji,
    required this.ramenDescription,
    required this.mapPosition,
    required this.primaryColor,
    required this.secondaryColor,
    required this.connectedTo,
    required this.arrivalQuote,
  });

  static const List<Region> all = [
    Region(
      id: 'hokkaido',
      name: 'Hokkaido',
      prefecture: 'Sapporo',
      ramenType: 'Miso Ramen',
      ramenEmoji: '🟡',
      ramenDescription:
          'Rich amber miso broth with sweet corn, melting butter, and thick wavy noodles',
      mapPosition: Offset(0.70, 0.10),
      primaryColor: Color(0xFF4A8FD9),
      secondaryColor: Color(0xFF2A6FAF),
      connectedTo: ['kanto'],
      arrivalQuote:
          "Amazing! We made it all the way to Hokkaido! The miso ramen here is legendary — that rich, warming broth with sweet corn and a pat of melting butter. Quick, snap that bowl before it gets cold!",
    ),
    Region(
      id: 'kanto',
      name: 'Kanto',
      prefecture: 'Tokyo',
      ramenType: 'Shoyu Ramen',
      ramenEmoji: '🟤',
      ramenDescription:
          'Crystal-clear soy sauce broth, the refined Tokyo classic',
      mapPosition: Offset(0.60, 0.42),
      primaryColor: Color(0xFFFF6B35),
      secondaryColor: Color(0xFFD4502A),
      connectedTo: ['hokkaido', 'kansai'],
      arrivalQuote:
          "Home sweet home! This is our base restaurant in Kanto. Tokyo shoyu ramen — clean, refined, perfectly balanced. The foundation of every great ramen chef's education!",
    ),
    Region(
      id: 'kansai',
      name: 'Kansai',
      prefecture: 'Osaka',
      ramenType: 'Shio Ramen',
      ramenEmoji: '⬜',
      ramenDescription:
          'Delicate salt-based broth, light and elegant — every ingredient shines',
      mapPosition: Offset(0.43, 0.54),
      primaryColor: Color(0xFF5BC47A),
      secondaryColor: Color(0xFF3A9A5A),
      connectedTo: ['kanto', 'kyushu'],
      arrivalQuote:
          "We're in Kansai! Osaka's shio ramen is all about subtlety — a crystal-clear salt broth that lets every ingredient shine. Don't let its simplicity fool you, this takes real skill!",
    ),
    Region(
      id: 'kyushu',
      name: 'Kyushu',
      prefecture: 'Fukuoka',
      ramenType: 'Tonkotsu Ramen',
      ramenEmoji: '⬜',
      ramenDescription:
          'Creamy white pork bone broth, ultra-rich and intensely flavourful',
      mapPosition: Offset(0.24, 0.70),
      primaryColor: Color(0xFFE8507A),
      secondaryColor: Color(0xFFC03060),
      connectedTo: ['kansai'],
      arrivalQuote:
          "Fukuoka, the birthplace of tonkotsu! That incredible milky-white pork bone broth simmered for hours — the smell alone is unreal. This is the big one. Get your camera ready!",
    ),
  ];

  static Region get homeRegion => all.firstWhere((r) => r.id == 'kanto');

  static Region byId(String id) => all.firstWhere((r) => r.id == id);
}
