/// Model for Deck
class DeckModel {
  final String id;
  final String name;
  final String description;
  final String authorId;
  final String authorName;
  final int flashcardCount;
  final int viewCount;
  final int favoriteCount;
  final bool isPublic;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeckModel({
    required this.id,
    required this.name,
    required this.description,
    required this.authorId,
    required this.authorName,
    required this.flashcardCount,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.isPublic = true,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'authorId': authorId,
      'authorName': authorName,
      'flashcardCount': flashcardCount,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'isPublic': isPublic,
      'isFavorite': isFavorite,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DeckModel.fromJson(Map<String, dynamic> json) {
    return DeckModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      authorId: json['authorId'],
      authorName: json['authorName'],
      flashcardCount: json['flashcardCount'],
      viewCount: json['viewCount'] ?? 0,
      favoriteCount: json['favoriteCount'] ?? 0,
      isPublic: json['isPublic'] ?? true,
      isFavorite: json['isFavorite'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

