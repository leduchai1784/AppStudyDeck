/// Model for Flashcard
class FlashcardModel {
  final String id;
  final String deckId;
  final String front;
  final String back;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int reviewCount;
  final bool isKnown;

  FlashcardModel({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.reviewCount = 0,
    this.isKnown = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deckId': deckId,
      'front': front,
      'back': back,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'reviewCount': reviewCount,
      'isKnown': isKnown,
    };
  }

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'],
      deckId: json['deckId'],
      front: json['front'],
      back: json['back'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      reviewCount: json['reviewCount'] ?? 0,
      isKnown: json['isKnown'] ?? false,
    );
  }
}

