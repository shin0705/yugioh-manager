// lib/models/deck_model.dart
class Deck {
  String id;
  String name;
  List<String> cardIds;
  int color; // 0xFFRRGGBB 형식으로 저장
  String coverImageUrl; // 대표 카드 이미지 URL

  static const int defaultColor = 0xFF22C55E;

  Deck({
    required this.id,
    required this.name,
    required this.cardIds,
    this.color = defaultColor,
    this.coverImageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'cardIds': cardIds,
      'color': color,
      'coverImageUrl': coverImageUrl,
    };
  }

  factory Deck.fromMap(String id, Map<String, dynamic> map) {
    return Deck(
      id: id,
      name: map['name'] ?? '',
      cardIds: List<String>.from(map['cardIds'] ?? []),
      color: (map['color'] as int?) ?? defaultColor,
      coverImageUrl: (map['coverImageUrl'] as String?) ?? '',
    );
  }
}
