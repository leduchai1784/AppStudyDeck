/// Constants for Firestore collections and fields
class FirestoreConstants {
  // Collection names
  static const String usersCollection = 'users';
  static const String decksCollection = 'decks';
  static const String flashcardsCollection = 'flashcards';
  static const String userDeckProgressCollection = 'user_deck_progress';
  static const String userFlashcardProgressCollection = 'user_flashcard_progress';
  static const String deckFavoritesCollection = 'deck_favorites';
  static const String reportsCollection = 'reports';
  static const String studySessionsCollection = 'study_sessions';
  static const String notificationsCollection = 'notifications';

  // Common field names
  static const String userId = 'userId';
  static const String deckId = 'deckId';
  static const String flashcardId = 'flashcardId';
  static const String reportId = 'reportId';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';

  // User fields
  static const String email = 'email';
  static const String name = 'name';
  static const String role = 'role';
  static const String isBlocked = 'isBlocked';
  static const String avatarUrl = 'avatarUrl';
  static const String lastLoginAt = 'lastLoginAt';
  static const String statistics = 'statistics';

  // Deck fields
  static const String authorId = 'authorId';
  static const String authorName = 'authorName';
  static const String flashcardCount = 'flashcardCount';
  static const String viewCount = 'viewCount';
  static const String favoriteCount = 'favoriteCount';
  static const String isPublic = 'isPublic';
  static const String approvalStatus = 'approvalStatus';
  static const String rejectionReason = 'rejectionReason';
  static const String tags = 'tags';
  static const String category = 'category';
  static const String difficulty = 'difficulty';
  static const String language = 'language';
  static const String approvedAt = 'approvedAt';
  static const String approvedBy = 'approvedBy';

  // Flashcard fields
  static const String front = 'front';
  static const String back = 'back';
  static const String order = 'order';
  static const String isActive = 'isActive';

  // Progress fields
  static const String progressId = 'progressId';
  static const String totalFlashcards = 'totalFlashcards';
  static const String studiedFlashcards = 'studiedFlashcards';
  static const String knownFlashcards = 'knownFlashcards';
  static const String unknownFlashcards = 'unknownFlashcards';
  static const String currentStreak = 'currentStreak';
  static const String lastStudyDate = 'lastStudyDate';
  static const String firstStudyDate = 'firstStudyDate';
  static const String totalStudyTime = 'totalStudyTime';
  static const String completionPercentage = 'completionPercentage';
  static const String isCompleted = 'isCompleted';
  static const String isKnown = 'isKnown';
  static const String reviewCount = 'reviewCount';
  static const String lastReviewDate = 'lastReviewDate';
  static const String nextReviewDate = 'nextReviewDate';
  static const String easeFactor = 'easeFactor';
  static const String interval = 'interval';
  static const String correctStreak = 'correctStreak';
  static const String incorrectStreak = 'incorrectStreak';

  // Report fields
  static const String reporterId = 'reporterId';
  static const String reporterName = 'reporterName';
  static const String reportType = 'reportType';
  static const String content = 'content';
  static const String targetType = 'targetType';
  static const String targetId = 'targetId';
  static const String status = 'status';
  static const String adminNotes = 'adminNotes';
  static const String resolvedBy = 'resolvedBy';
  static const String resolvedAt = 'resolvedAt';

  // Study session fields
  static const String sessionId = 'sessionId';
  static const String startTime = 'startTime';
  static const String endTime = 'endTime';
  static const String duration = 'duration';
  static const String flashcardsStudied = 'flashcardsStudied';
  static const String flashcardsKnown = 'flashcardsKnown';
  static const String flashcardsUnknown = 'flashcardsUnknown';

  // Approval status values
  static const String approvalStatusPending = 'pending';
  static const String approvalStatusApproved = 'approved';
  static const String approvalStatusRejected = 'rejected';

  // Report status values
  static const String reportStatusPending = 'pending';
  static const String reportStatusResolved = 'resolved';
  static const String reportStatusRejected = 'rejected';

  // Report type values
  static const String reportTypeInappropriateContent = 'inappropriate_content';
  static const String reportTypeSpam = 'spam';
  static const String reportTypeCopyright = 'copyright';
  static const String reportTypeOther = 'other';

  // Target type values
  static const String targetTypeDeck = 'deck';
  static const String targetTypeFlashcard = 'flashcard';
  static const String targetTypeUser = 'user';

  // Role values
  static const String roleAdmin = 'admin';
  static const String roleUser = 'user';

  // Difficulty values
  static const String difficultyBeginner = 'beginner';
  static const String difficultyIntermediate = 'intermediate';
  static const String difficultyAdvanced = 'advanced';
}
