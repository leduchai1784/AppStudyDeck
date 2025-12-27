import '../models/deck_model.dart';
import '../models/flashcard_model.dart';

/// Mock API for development and testing
/// This file contains mock data and functions to simulate API calls

class MockApi {
  // Mock users database
  static final Map<String, Map<String, dynamic>> _mockUsers = {
    'admin@example.com': {
      'email': 'admin@example.com',
      'password': 'admin123',
      'name': 'Admin User',
      'role': 'admin',
      'id': '1',
      'isBlocked': false,
      'createdAt': DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
    },
    'user@example.com': {
      'email': 'user@example.com',
      'password': 'user123',
      'name': 'Regular User',
      'role': 'user',
      'id': '2',
      'isBlocked': false,
      'createdAt': DateTime.now().subtract(const Duration(days: 100)).toIso8601String(),
    },
  };

  /// Mock login function
  /// Returns user data if credentials are valid, null otherwise
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    final user = _mockUsers[email];
    
    if (user != null && user['password'] == password) {
      // Return user data without password
      final userData = Map<String, dynamic>.from(user);
      userData.remove('password');
      return userData;
    }
    
    return null;
  }

  /// Mock register function
  static Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String name,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if user already exists
    if (_mockUsers.containsKey(email)) {
      return null; // User already exists
    }
    
    // Create new user
    final newUser = {
      'email': email,
      'password': password,
      'name': name,
      'role': 'user',
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    
    _mockUsers[email] = newUser;
    
    // Return user data without password
    final userData = Map<String, dynamic>.from(newUser);
    userData.remove('password');
    return userData;
  }

  /// Get user by email
  static Map<String, dynamic>? getUserByEmail(String email) {
    final user = _mockUsers[email];
    if (user != null) {
      final userData = Map<String, dynamic>.from(user);
      userData.remove('password');
      return userData;
    }
    return null;
  }

  /// Check if user is admin
  static bool isAdmin(String email) {
    final user = _mockUsers[email];
    return user?['role'] == 'admin';
  }

  // Mock decks database
  static final Map<String, DeckModel> _mockDecks = {
    'deck1': DeckModel(
      id: 'deck1',
      name: 'Từ vựng Tiếng Anh cơ bản',
      description: 'Học các từ vựng tiếng Anh thông dụng nhất trong cuộc sống hàng ngày. Deck này bao gồm 10 flashcard về các từ vựng cơ bản.',
      authorId: '2',
      authorName: 'Regular User',
      flashcardCount: 10,
      viewCount: 156,
      favoriteCount: 23,
      isPublic: true,
      isFavorite: false,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  };

  // Deck approval status: 'pending', 'approved', 'rejected'
  static final Map<String, String> _deckApprovalStatus = {
    'deck1': 'approved',
  };

  // Mock reports database
  static final List<Map<String, dynamic>> _mockReports = [];

  // Mock flashcards database
  static final Map<String, FlashcardModel> _mockFlashcards = {
    'fc1': FlashcardModel(
      id: 'fc1',
      deckId: 'deck1',
      front: 'Hello',
      back: 'Xin chào',
      tags: ['chào hỏi', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc2': FlashcardModel(
      id: 'fc2',
      deckId: 'deck1',
      front: 'Thank you',
      back: 'Cảm ơn',
      tags: ['lịch sự', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc3': FlashcardModel(
      id: 'fc3',
      deckId: 'deck1',
      front: 'Goodbye',
      back: 'Tạm biệt',
      tags: ['chào hỏi', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc4': FlashcardModel(
      id: 'fc4',
      deckId: 'deck1',
      front: 'Please',
      back: 'Xin vui lòng / Làm ơn',
      tags: ['lịch sự', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc5': FlashcardModel(
      id: 'fc5',
      deckId: 'deck1',
      front: 'Sorry',
      back: 'Xin lỗi',
      tags: ['lịch sự', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc6': FlashcardModel(
      id: 'fc6',
      deckId: 'deck1',
      front: 'Yes',
      back: 'Có / Vâng / Đúng',
      tags: ['cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc7': FlashcardModel(
      id: 'fc7',
      deckId: 'deck1',
      front: 'No',
      back: 'Không',
      tags: ['cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc8': FlashcardModel(
      id: 'fc8',
      deckId: 'deck1',
      front: 'Water',
      back: 'Nước',
      tags: ['đồ vật', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc9': FlashcardModel(
      id: 'fc9',
      deckId: 'deck1',
      front: 'Food',
      back: 'Thức ăn / Đồ ăn',
      tags: ['đồ vật', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    'fc10': FlashcardModel(
      id: 'fc10',
      deckId: 'deck1',
      front: 'Friend',
      back: 'Bạn bè / Người bạn',
      tags: ['quan hệ', 'cơ bản'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  };

  /// Get all decks
  static Future<List<DeckModel>> getDecks({String? userId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (userId != null) {
      // Return decks by specific user
      return _mockDecks.values
          .where((deck) => deck.authorId == userId)
          .toList();
    }
    
    // Return all public decks
    return _mockDecks.values.where((deck) => deck.isPublic).toList();
  }

  /// Get deck by ID
  static Future<DeckModel?> getDeckById(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockDecks[deckId];
  }

  /// Get flashcards by deck ID
  static Future<List<FlashcardModel>> getFlashcardsByDeckId(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockFlashcards.values
        .where((flashcard) => flashcard.deckId == deckId)
        .toList();
  }

  /// Get flashcard by ID
  static Future<FlashcardModel?> getFlashcardById(String flashcardId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockFlashcards[flashcardId];
  }

  /// Create new deck
  static Future<DeckModel> createDeck({
    required String name,
    required String description,
    required String authorId,
    required String authorName,
    bool isPublic = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final newDeck = DeckModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      authorId: authorId,
      authorName: authorName,
      flashcardCount: 0,
      isPublic: isPublic,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _mockDecks[newDeck.id] = newDeck;
    return newDeck;
  }

  /// Create new flashcard
  static Future<FlashcardModel> createFlashcard({
    required String deckId,
    required String front,
    required String back,
    List<String> tags = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final newFlashcard = FlashcardModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deckId: deckId,
      front: front,
      back: back,
      tags: tags,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    _mockFlashcards[newFlashcard.id] = newFlashcard;
    
    // Update deck flashcard count
    final deck = _mockDecks[deckId];
    if (deck != null) {
      final updatedDeck = DeckModel(
        id: deck.id,
        name: deck.name,
        description: deck.description,
        authorId: deck.authorId,
        authorName: deck.authorName,
        flashcardCount: deck.flashcardCount + 1,
        viewCount: deck.viewCount,
        favoriteCount: deck.favoriteCount,
        isPublic: deck.isPublic,
        isFavorite: deck.isFavorite,
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
      );
      _mockDecks[deckId] = updatedDeck;
    }
    
    return newFlashcard;
  }

  /// Update flashcard
  static Future<FlashcardModel> updateFlashcard({
    required String flashcardId,
    required String front,
    required String back,
    List<String> tags = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final flashcard = _mockFlashcards[flashcardId];
    if (flashcard == null) {
      throw Exception('Flashcard not found');
    }
    
    final updatedFlashcard = FlashcardModel(
      id: flashcard.id,
      deckId: flashcard.deckId,
      front: front,
      back: back,
      tags: tags,
      createdAt: flashcard.createdAt,
      updatedAt: DateTime.now(),
      reviewCount: flashcard.reviewCount,
      isKnown: flashcard.isKnown,
    );
    
    _mockFlashcards[flashcardId] = updatedFlashcard;
    return updatedFlashcard;
  }

  /// Delete flashcard
  static Future<void> deleteFlashcard(String flashcardId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final flashcard = _mockFlashcards[flashcardId];
    if (flashcard != null) {
      _mockFlashcards.remove(flashcardId);
      // Update deck flashcard count
      final deck = _mockDecks[flashcard.deckId];
      if (deck != null) {
        final updatedDeck = DeckModel(
          id: deck.id,
          name: deck.name,
          description: deck.description,
          authorId: deck.authorId,
          authorName: deck.authorName,
          flashcardCount: deck.flashcardCount - 1,
          viewCount: deck.viewCount,
          favoriteCount: deck.favoriteCount,
          isPublic: deck.isPublic,
          isFavorite: deck.isFavorite,
          createdAt: deck.createdAt,
          updatedAt: DateTime.now(),
        );
        _mockDecks[flashcard.deckId] = updatedDeck;
      }
    }
  }

  /// Update deck
  static Future<DeckModel> updateDeck({
    required String deckId,
    String? name,
    String? description,
    bool? isPublic,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final deck = _mockDecks[deckId];
    if (deck == null) {
      throw Exception('Deck not found');
    }
    
    final updatedDeck = DeckModel(
      id: deck.id,
      name: name ?? deck.name,
      description: description ?? deck.description,
      authorId: deck.authorId,
      authorName: deck.authorName,
      flashcardCount: deck.flashcardCount,
      viewCount: deck.viewCount,
      favoriteCount: deck.favoriteCount,
      isPublic: isPublic ?? deck.isPublic,
      isFavorite: deck.isFavorite,
      createdAt: deck.createdAt,
      updatedAt: DateTime.now(),
    );
    
    _mockDecks[deckId] = updatedDeck;
    return updatedDeck;
  }

  /// Toggle favorite deck
  static Future<void> toggleFavoriteDeck(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final deck = _mockDecks[deckId];
    if (deck != null) {
      final updatedDeck = DeckModel(
        id: deck.id,
        name: deck.name,
        description: deck.description,
        authorId: deck.authorId,
        authorName: deck.authorName,
        flashcardCount: deck.flashcardCount,
        viewCount: deck.viewCount,
        favoriteCount: deck.isFavorite ? deck.favoriteCount - 1 : deck.favoriteCount + 1,
        isPublic: deck.isPublic,
        isFavorite: !deck.isFavorite,
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
      );
      _mockDecks[deckId] = updatedDeck;
    }
  }

  /// Mark flashcard as known/unknown
  static Future<void> markFlashcardKnown(String flashcardId, bool isKnown) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final flashcard = _mockFlashcards[flashcardId];
    if (flashcard != null) {
      final updatedFlashcard = FlashcardModel(
        id: flashcard.id,
        deckId: flashcard.deckId,
        front: flashcard.front,
        back: flashcard.back,
        tags: flashcard.tags,
        createdAt: flashcard.createdAt,
        updatedAt: DateTime.now(),
        reviewCount: flashcard.reviewCount + 1,
        isKnown: isKnown,
      );
      _mockFlashcards[flashcardId] = updatedFlashcard;
    }
  }

  /// Get all users (for admin)
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockUsers.values.map((user) {
      final userData = Map<String, dynamic>.from(user);
      userData.remove('password');
      return userData;
    }).toList();
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final user = _mockUsers.values.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => {},
    );
    if (user.isEmpty) return null;
    final userData = Map<String, dynamic>.from(user);
    userData.remove('password');
    return userData;
  }

  /// Update user
  static Future<Map<String, dynamic>> updateUser({
    required String userId,
    String? name,
    String? email,
    String? role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final userEntry = _mockUsers.entries.firstWhere(
      (e) => e.value['id'] == userId,
      orElse: () => throw Exception('User not found'),
    );
    
    if (name != null) userEntry.value['name'] = name;
    if (email != null) {
      _mockUsers.remove(userEntry.key);
      userEntry.value['email'] = email;
      _mockUsers[email] = userEntry.value;
    }
    if (role != null) userEntry.value['role'] = role;
    
    final userData = Map<String, dynamic>.from(userEntry.value);
    userData.remove('password');
    return userData;
  }

  /// Block/Unblock user
  static Future<void> toggleBlockUser(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final user = _mockUsers.values.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => throw Exception('User not found'),
    );
    user['isBlocked'] = !(user['isBlocked'] ?? false);
  }

  /// Reset user password
  static Future<void> resetUserPassword(String userId, String newPassword) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final user = _mockUsers.values.firstWhere(
      (u) => u['id'] == userId,
      orElse: () => throw Exception('User not found'),
    );
    user['password'] = newPassword;
  }

  /// Get all decks (for admin - includes all statuses)
  static Future<List<DeckModel>> getAllDecksForAdmin() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockDecks.values.toList();
  }

  /// Get deck approval status
  static String? getDeckApprovalStatus(String deckId) {
    return _deckApprovalStatus[deckId] ?? 'pending';
  }

  /// Approve deck
  static Future<void> approveDeck(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _deckApprovalStatus[deckId] = 'approved';
    final deck = _mockDecks[deckId];
    if (deck != null) {
      final updatedDeck = DeckModel(
        id: deck.id,
        name: deck.name,
        description: deck.description,
        authorId: deck.authorId,
        authorName: deck.authorName,
        flashcardCount: deck.flashcardCount,
        viewCount: deck.viewCount,
        favoriteCount: deck.favoriteCount,
        isPublic: true,
        isFavorite: deck.isFavorite,
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
      );
      _mockDecks[deckId] = updatedDeck;
    }
  }

  /// Reject deck
  static Future<void> rejectDeck(String deckId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _deckApprovalStatus[deckId] = 'rejected';
    final deck = _mockDecks[deckId];
    if (deck != null) {
      final updatedDeck = DeckModel(
        id: deck.id,
        name: deck.name,
        description: deck.description,
        authorId: deck.authorId,
        authorName: deck.authorName,
        flashcardCount: deck.flashcardCount,
        viewCount: deck.viewCount,
        favoriteCount: deck.favoriteCount,
        isPublic: false,
        isFavorite: deck.isFavorite,
        createdAt: deck.createdAt,
        updatedAt: DateTime.now(),
      );
      _mockDecks[deckId] = updatedDeck;
    }
  }

  /// Delete deck
  static Future<void> deleteDeck(String deckId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDecks.remove(deckId);
    _deckApprovalStatus.remove(deckId);
    // Remove all flashcards in this deck
    _mockFlashcards.removeWhere((key, value) => value.deckId == deckId);
  }

  /// Create report
  static Future<Map<String, dynamic>> createReport({
    required String reporterId,
    required String reporterName,
    required String reportType,
    required String content,
    String? deckId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final report = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'reporterId': reporterId,
      'reporterName': reporterName,
      'reportType': reportType,
      'content': content,
      'deckId': deckId,
      'status': 'pending',
      'createdAt': DateTime.now().toIso8601String(),
    };
    _mockReports.add(report);
    return report;
  }

  /// Get all reports
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_mockReports);
  }

  /// Get report by ID
  static Future<Map<String, dynamic>?> getReportById(String reportId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _mockReports.firstWhere((r) => r['id'] == reportId);
    } catch (e) {
      return null;
    }
  }

  /// Update report status
  static Future<void> updateReportStatus(String reportId, String status) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final report = _mockReports.firstWhere(
      (r) => r['id'] == reportId,
      orElse: () => throw Exception('Report not found'),
    );
    report['status'] = status;
  }

  /// Get statistics for admin dashboard
  static Future<Map<String, dynamic>> getAdminStatistics() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return {
      'totalUsers': _mockUsers.length,
      'totalDecks': _mockDecks.length,
      'totalFlashcards': _mockFlashcards.length,
      'pendingReports': _mockReports.where((r) => r['status'] == 'pending').length,
      'pendingDecks': _deckApprovalStatus.values.where((s) => s == 'pending').length,
    };
  }

  /// Search decks
  static Future<List<DeckModel>> searchDecks(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lowerQuery = query.toLowerCase();
    return _mockDecks.values.where((deck) {
      return deck.name.toLowerCase().contains(lowerQuery) ||
          deck.description.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Search users
  static Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final lowerQuery = query.toLowerCase();
    return _mockUsers.values.where((user) {
      return user['name'].toString().toLowerCase().contains(lowerQuery) ||
          user['email'].toString().toLowerCase().contains(lowerQuery);
    }).map((user) {
      final userData = Map<String, dynamic>.from(user);
      userData.remove('password');
      return userData;
    }).toList();
  }
}

