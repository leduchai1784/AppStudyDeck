import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Repository for Firestore database operations
/// This class provides methods to interact with Firestore collections
class FirestoreRepository {
  // Singleton instance
  static final FirestoreRepository _instance = FirestoreRepository._internal();
  factory FirestoreRepository() => _instance;
  FirestoreRepository._internal();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference get _decksCollection => _firestore.collection('decks');
  CollectionReference get _flashcardsCollection => _firestore.collection('flashcards');
  CollectionReference get _notificationsCollection => _firestore.collection('notifications');
  CollectionReference get _userDeckProgressCollection => _firestore.collection('user_deck_progress');
  CollectionReference get _userFlashcardProgressCollection => _firestore.collection('user_flashcard_progress');
  CollectionReference get _deckFavoritesCollection => _firestore.collection('deck_favorites');
  CollectionReference get _reportsCollection => _firestore.collection('reports');
  CollectionReference get _studySessionsCollection => _firestore.collection('study_sessions');

  // ==================== Helper Methods ====================

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Safely get data from Firestore document
  Map<String, dynamic>? _safeGetDocumentData(DocumentSnapshot doc) {
    try {
      final rawData = doc.data();
      if (rawData == null) {
        return null;
      }
      
      // Debug: Log the actual type we receive
      debugPrint('🔍 Document ${doc.id} data type: ${rawData.runtimeType}');
      
      // Check if data is a List (unexpected case)
      if (rawData is List) {
        debugPrint('❌ ERROR: Document ${doc.id} returned List instead of Map');
        debugPrint('❌ List content: $rawData');
        debugPrint('❌ List length: ${rawData.length}');
        
        // If it's a List with one element that might be a Map, try to extract it
        if (rawData.isNotEmpty && rawData[0] is Map) {
          debugPrint('⚠️ Attempting to extract Map from first List element');
          try {
            final extractedMap = rawData[0] as Map;
            return Map<String, dynamic>.from(extractedMap);
          } catch (e) {
            debugPrint('❌ Failed to extract Map from List: $e');
            throw Exception('Document ${doc.id} returned List<Object?> instead of Map. First element type: ${rawData[0].runtimeType}. Error: $e');
          }
        }
        
        // If List is empty or doesn't contain a Map, throw error
        throw Exception('Document ${doc.id} returned List<Object?> instead of Map<String, dynamic>. List length: ${rawData.length}');
      }
      
      // Check if data is a Map
      if (rawData is Map<String, dynamic>) {
        return rawData;
      }
      
      // Try to convert other Map types to Map<String, dynamic>
      if (rawData is Map) {
        debugPrint('⚠️ Converting Map<dynamic, dynamic> to Map<String, dynamic> for document ${doc.id}');
        try {
          return Map<String, dynamic>.from(rawData);
        } catch (e) {
          debugPrint('❌ Failed to convert Map: $e');
          throw Exception('Failed to convert Map to Map<String, dynamic> for document ${doc.id}: $e');
        }
      }
      
      // Unknown type
      debugPrint('❌ ERROR: Unknown data type ${rawData.runtimeType} for document ${doc.id}');
      throw Exception('Document ${doc.id} has unexpected data type: ${rawData.runtimeType}. Expected Map<String, dynamic> or Map, but got: $rawData');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _safeGetDocumentData for document ${doc.id}: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get document data for ${doc.id}: $e');
    }
  }

  /// Convert Firestore document to Map with proper type conversion
  Map<String, dynamic> _convertDocumentData(Map<String, dynamic> data) {
    final converted = <String, dynamic>{};
    data.forEach((key, value) {
      if (value == null) {
        converted[key] = null;
      } else if (value is Timestamp) {
        converted[key] = value.toDate().toIso8601String();
      } else if (value is GeoPoint) {
        converted[key] = {'latitude': value.latitude, 'longitude': value.longitude};
      } else if (value is List) {
        // Handle List safely
        converted[key] = value.map((item) {
          if (item == null) return null;
          if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          if (item is Map) {
            // Recursively convert nested maps
            return _convertDocumentData(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else if (value is Map) {
        // Handle nested Map (like statistics object)
        converted[key] = _convertDocumentData(Map<String, dynamic>.from(value));
      } else {
        converted[key] = value;
      }
    });
    return converted;
  }

  /// Prepare data for Firestore (convert DateTime to Timestamp)
  Map<String, dynamic> _prepareDataForFirestore(Map<String, dynamic> data) {
    final prepared = <String, dynamic>{};
    data.forEach((key, value) {
      try {
        if (value == null) {
          prepared[key] = null;
        } else if (value is DateTime) {
          prepared[key] = Timestamp.fromDate(value);
        } else if (value is Map) {
          // Recursively prepare nested maps (like statistics object)
          // Handle both Map<dynamic, dynamic> and Map<String, dynamic>
          Map<String, dynamic> mapValue;
          if (value is Map<String, dynamic>) {
            mapValue = value;
          } else {
            // Convert any Map type to Map<String, dynamic>
            mapValue = Map<String, dynamic>.from(value);
          }
          prepared[key] = _prepareDataForFirestore(mapValue);
        } else if (value is List) {
          // Handle List - convert DateTime items
          prepared[key] = value.map((item) {
            if (item == null) return null;
            if (item is DateTime) {
              return Timestamp.fromDate(item);
            } else if (item is Map) {
              // Handle nested Map in List
              if (item is Map<String, dynamic>) {
                return _prepareDataForFirestore(item);
              } else {
                return _prepareDataForFirestore(Map<String, dynamic>.from(item));
              }
            }
            return item;
          }).toList();
        } else {
          // Keep primitive types as-is (String, int, double, bool, etc.)
          prepared[key] = value;
        }
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR preparing data for key "$key": $e');
        debugPrint('Value type: ${value.runtimeType}');
        debugPrint('Value: $value');
        debugPrint('Stack trace: $stackTrace');
        // Try to keep original value if conversion fails
        prepared[key] = value;
      }
    });
    return prepared;
  }

  // ==================== Users Collection ====================

  /// Create or update user document
  Future<void> createOrUpdateUser({
    required String userId,
    required Map<String, dynamic> userData,
  }) async {
    try {
      // Verify user is authenticated
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        debugPrint('❌ ERROR: User not authenticated. Cannot create user document.');
        throw Exception('User not authenticated. Cannot create user document.');
      }
      
      if (currentUserId != userId) {
        debugPrint('❌ ERROR: User ID mismatch. Current: $currentUserId, Requested: $userId');
        throw Exception('User ID mismatch. Current: $currentUserId, Requested: $userId');
      }
      
      debugPrint('📝 Preparing user data for Firestore...');
      debugPrint('📝 Input data keys: ${userData.keys.toList()}');
      debugPrint('📝 Input statistics type: ${userData['statistics'].runtimeType}');
      debugPrint('📝 Input statistics: ${userData['statistics']}');
      
      final data = _prepareDataForFirestore(userData);
      
      // Always set timestamps using serverTimestamp
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      // Only set createdAt if document doesn't exist (check first)
      final docExists = (await _usersCollection.doc(userId).get()).exists;
      if (!docExists) {
        data['createdAt'] = FieldValue.serverTimestamp();
        debugPrint('📝 Document does not exist, will create new document');
      } else {
        debugPrint('📝 Document exists, will update existing document');
      }

      debugPrint('💾 Saving user document to Firestore: users/$userId');
      debugPrint('💾 Data keys: ${data.keys.toList()}');
      debugPrint('💾 Statistics type: ${data['statistics'].runtimeType}');
      debugPrint('💾 Statistics: ${data['statistics']}');
      debugPrint('💾 Email: ${data['email']}');
      debugPrint('💾 Name: ${data['name']}');
      debugPrint('💾 Role: ${data['role']}');
      
      // Use set with merge: true to preserve existing fields if document exists
      try {
        await _usersCollection.doc(userId).set(data, SetOptions(merge: true));
        debugPrint('✅ Document written to Firestore');
      } on FirebaseException catch (firebaseError) {
        debugPrint('❌ FirebaseException: ${firebaseError.code} - ${firebaseError.message}');
        debugPrint('❌ Error details: ${firebaseError.toString()}');
        debugPrint('❌ Stack trace: ${firebaseError.stackTrace}');
        
        // Provide more specific error messages with error code
        String errorMessage;
        switch (firebaseError.code) {
          case 'permission-denied':
            errorMessage = 'PERMISSION_DENIED: Không có quyền ghi vào Firestore. Vui lòng kiểm tra Security Rules.';
            break;
          case 'unavailable':
            errorMessage = 'UNAVAILABLE: Firestore không khả dụng. Vui lòng kiểm tra kết nối internet.';
            break;
          case 'deadline-exceeded':
            errorMessage = 'DEADLINE_EXCEEDED: Request timeout. Vui lòng thử lại.';
            break;
          case 'resource-exhausted':
            errorMessage = 'RESOURCE_EXHAUSTED: Quá nhiều requests. Vui lòng thử lại sau.';
            break;
          case 'failed-precondition':
            errorMessage = 'FAILED_PRECONDITION: Điều kiện không đáp ứng. Vui lòng thử lại.';
            break;
          case 'aborted':
            errorMessage = 'ABORTED: Request bị hủy. Vui lòng thử lại.';
            break;
          case 'out-of-range':
            errorMessage = 'OUT_OF_RANGE: Dữ liệu không hợp lệ.';
            break;
          case 'unimplemented':
            errorMessage = 'UNIMPLEMENTED: Tính năng chưa được triển khai.';
            break;
          case 'internal':
            errorMessage = 'INTERNAL: Lỗi nội bộ của Firestore. Vui lòng thử lại sau.';
            break;
          case 'unauthenticated':
            errorMessage = 'UNAUTHENTICATED: Chưa xác thực. Vui lòng đăng nhập lại.';
            break;
          default:
            errorMessage = 'Firestore error (${firebaseError.code}): ${firebaseError.message ?? 'Unknown error'}';
        }
        
        throw Exception(errorMessage);
      } catch (setError, stackTrace) {
        debugPrint('❌ Error during set operation: $setError');
        debugPrint('❌ Error type: ${setError.runtimeType}');
        debugPrint('❌ Stack trace: $stackTrace');
        
        // If it's not already an Exception with a message, wrap it
        if (setError is! Exception || setError.toString().isEmpty) {
          throw Exception('Failed to create user document: $setError');
        }
        
        rethrow;
      }
      
      debugPrint('✅ Document set successfully, verifying...');
      
      // Verify document was created/updated
      await Future.delayed(const Duration(milliseconds: 300)); // Wait for Firestore to sync
      final verifyDoc = await _usersCollection.doc(userId).get();
      if (!verifyDoc.exists) {
        debugPrint('❌ ERROR: Document was not created in Firestore');
        throw Exception('Document was not created in Firestore. Có thể do Security Rules.');
      }
      
      final verifyData = verifyDoc.data();
      debugPrint('✅ Verified: User document exists in Firestore');
      if (verifyData is Map<String, dynamic>) {
        debugPrint('✅ Document data keys: ${verifyData.keys.toList()}');
      } else {
        debugPrint('✅ Document data type: ${verifyData.runtimeType}');
      }
      
    } on FirebaseException catch (e) {
      debugPrint('❌ FirebaseException in createOrUpdateUser: ${e.code} - ${e.message}');
      throw Exception('Firestore error: ${e.code} - ${e.message}');
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in createOrUpdateUser: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to create/update user: $e');
    }
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      debugPrint('🔍 Getting user document: users/$userId');
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists) {
        debugPrint('⚠️ User document does not exist: users/$userId');
        return null;
      }
      
      debugPrint('✅ User document exists: users/$userId');
      
      // Safely get data using helper function
      final data = _safeGetDocumentData(doc);
      if (data == null) {
        debugPrint('⚠️ User document data is null: users/$userId');
        return null;
      }
      
      debugPrint('✅ User document data retrieved successfully');
      debugPrint('📄 Data keys: ${data.keys.toList()}');
      
      data['userId'] = doc.id;
      final convertedData = _convertDocumentData(data);
      debugPrint('✅ User data converted successfully');
      return convertedData;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getUserById for userId $userId: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get user $userId: $e');
    }
  }

  /// Get all users (admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('User document ${doc.id} has null data');
        }
        data['userId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all users: $e');
    }
  }

  /// Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      final data = _prepareDataForFirestore(updates);
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _usersCollection.doc(userId).update(data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  // ==================== Decks Collection ====================

  /// Create deck
  /// Post-moderation model: deck public ngay khi tạo (không cần duyệt)
  /// Status: 'private' (riêng tư), 'public' (công khai), 'reported' (bị báo cáo), 'hidden' (admin ẩn)
  /// Default: isPublic = false, status = 'private'
  Future<String> createDeck(Map<String, dynamic> deckData) async {
    try {
      final data = _prepareDataForFirestore(deckData);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      
      // Set default values if not provided
      if (!data.containsKey('isPublic')) {
        data['isPublic'] = false; // Default: không công khai
      }
      
      // New status field (replaces approvalStatus)
      // If not provided, set based on isPublic
      if (!data.containsKey('status')) {
        data['status'] = data['isPublic'] == true ? 'public' : 'private';
      }
      
      // Legacy support: if approvalStatus exists, convert to status
      if (data.containsKey('approvalStatus') && !data.containsKey('status')) {
        final approvalStatus = data['approvalStatus'];
        if (approvalStatus == 'approved') {
          data['status'] = 'public';
        } else if (approvalStatus == 'rejected') {
          data['status'] = 'hidden';
        } else {
          data['status'] = data['isPublic'] == true ? 'public' : 'private';
        }
      }
      
      data['flashcardCount'] = 0;
      data['viewCount'] = 0;
      data['favoriteCount'] = 0;

      final docRef = await _decksCollection.add(data);
      final deckId = docRef.id;
      
      // Notify admins if deck is public
      if (data['isPublic'] == true && data['status'] == 'public') {
        try {
          await _notifyAdminsAboutNewPublicDeck(deckId, data);
        } catch (notifyError) {
          // Don't fail deck creation if notification fails
          debugPrint('⚠️ Error notifying admins about public deck: $notifyError');
        }
      }
      
      debugPrint('✅ Deck created: $deckId, status: ${data['status']}, isPublic: ${data['isPublic']}');
      
      return deckId;
    } catch (e) {
      throw Exception('Failed to create deck: $e');
    }
  }

  /// Notify all admins about a deck that became public
  /// CHỈ gửi cho admin, KHÔNG gửi cho user
  Future<void> _notifyAdminsAboutNewPublicDeck(String deckId, Map<String, dynamic> deckData) async {
    try {
      // Get all admin users
      final adminUsers = await _getAdminUsers();
      if (adminUsers.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return;
      }

      final deckName = deckData['name'] ?? 'Unnamed Deck';
      final authorName = deckData['authorName'] ?? 'Unknown User';

      // Create notification for each admin ONLY (not for the author)
      final batch = _firestore.batch();
      for (var admin in adminUsers) {
        final adminId = admin['userId'] as String;
        final notificationRef = _notificationsCollection.doc();
        
        batch.set(notificationRef, {
          'userId': adminId, // CHỈ gửi cho admin
          'type': 'deck_public',
          'title': 'Deck đã được công khai',
          'message': 'Deck "$deckName" của $authorName đã được công khai',
          'data': {
            'deckId': deckId,
            'authorId': deckData['authorId'],
            'authorName': authorName,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Notified ${adminUsers.length} admin(s) about public deck: $deckId');
      debugPrint('ℹ️ User (author) will NOT receive notification about their own deck');
    } catch (e) {
      debugPrint('❌ Error notifying admins: $e');
      throw Exception('Failed to notify admins: $e');
    }
  }

  /// Get all admin users
  Future<List<Map<String, dynamic>>> _getAdminUsers() async {
    try {
      final snapshot = await _usersCollection
          .where('role', isEqualTo: 'admin')
          .get();

      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Admin user document ${doc.id} has null data');
        }
        data['userId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting admin users: $e');
      return [];
    }
  }

  /// Get deck by ID
  Future<Map<String, dynamic>?> getDeckById(String deckId) async {
    try {
      final doc = await _decksCollection.doc(deckId).get();
      if (!doc.exists) {
        return null;
      }
      final data = _safeGetDocumentData(doc);
      if (data == null) {
        return null;
      }
      data['deckId'] = doc.id;
      return _convertDocumentData(data);
    } catch (e) {
      throw Exception('Failed to get deck: $e');
    }
  }

  /// Get decks by author ID
  Future<List<Map<String, dynamic>>> getDecksByAuthor(String authorId) async {
    try {
      debugPrint('🔍 Getting decks for authorId: $authorId');
      
      // Try query with orderBy first (requires index)
      try {
        final snapshot = await _decksCollection
            .where('authorId', isEqualTo: authorId)
            .orderBy('createdAt', descending: true)
            .get();
        
        debugPrint('✅ Query with orderBy succeeded, found ${snapshot.docs.length} decks');
        
        final decks = snapshot.docs.map((doc) {
          final data = _safeGetDocumentData(doc);
          if (data == null) {
            throw Exception('Document ${doc.id} has null data');
          }
          data['deckId'] = doc.id;
          return _convertDocumentData(data);
        }).toList();
        
        // Sort by createdAt descending (client-side fallback if needed)
        decks.sort((a, b) {
          final aDate = a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime(1970);
          final bDate = b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime(1970);
          return bDate.compareTo(aDate);
        });
        
        return decks;
      } on FirebaseException catch (firebaseError) {
        // If index is missing, try without orderBy as fallback
        if (firebaseError.code == 'failed-precondition' || 
            firebaseError.message?.contains('index') == true ||
            firebaseError.message?.contains('FAILED_PRECONDITION') == true) {
          debugPrint('⚠️ Index not ready, using fallback query without orderBy');
          
          // Fallback: Query without orderBy, then sort client-side
          final snapshot = await _decksCollection
              .where('authorId', isEqualTo: authorId)
              .get();
          
          debugPrint('✅ Fallback query succeeded, found ${snapshot.docs.length} decks');
          
          final decks = snapshot.docs.map((doc) {
            final data = _safeGetDocumentData(doc);
            if (data == null) {
              throw Exception('Document ${doc.id} has null data');
            }
            data['deckId'] = doc.id;
            return _convertDocumentData(data);
          }).toList();
          
          // Sort by createdAt descending (client-side)
          decks.sort((a, b) {
            final aDate = a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime(1970);
            final bDate = b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime(1970);
            return bDate.compareTo(aDate);
          });
          
          return decks;
        } else {
          // Re-throw other Firebase errors
          debugPrint('❌ Firebase error: ${firebaseError.code} - ${firebaseError.message}');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getDecksByAuthor: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get decks by author: $e');
    }
  }

  /// Get public decks (post-moderation model)
  /// Public decks are visible immediately, only hidden decks are excluded
  Future<List<Map<String, dynamic>>> getPublicDecks({
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool includePending = false, // Deprecated, kept for compatibility
  }) async {
    try {
      Query query;
      
      // Post-moderation: public decks ngay khi tạo, chỉ ẩn deck bị report/hidden
      // Query: isPublic = true AND status != 'hidden'
      debugPrint('📚 Querying public decks (post-moderation, excluding hidden)...');
      query = _decksCollection
          .where('isPublic', isEqualTo: true)
          .where('status', isNotEqualTo: 'hidden')
          .orderBy('status')
          .orderBy('createdAt', descending: true)
          .limit(limit);
      
      // Fallback: if status field doesn't exist (legacy data), use old query
      // This handles decks created before the migration

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      debugPrint('✅ Public decks query succeeded, found ${snapshot.docs.length} decks');
      
      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Document ${doc.id} has null data');
        }
        data['deckId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } on FirebaseException catch (firebaseError) {
      debugPrint('⚠️ Firebase error in getPublicDecks: ${firebaseError.code} - ${firebaseError.message}');
      
      // If index is missing or being built, try fallback queries
      if (firebaseError.code == 'failed-precondition' || 
          firebaseError.message?.contains('index') == true ||
          firebaseError.message?.contains('FAILED_PRECONDITION') == true) {
        debugPrint('⚠️ Index not ready, trying fallback queries...');
        
        try {
          // Fallback 1: Try without orderBy (no index needed)
          debugPrint('🔄 Fallback 1: Query without orderBy...');
          Query fallbackQuery = _decksCollection
              .where('isPublic', isEqualTo: true);
          
          // Post-moderation: exclude hidden decks
          // Try new status field first, fallback to old approvalStatus for legacy data
          try {
            fallbackQuery = fallbackQuery.where('status', isNotEqualTo: 'hidden');
          } catch (e) {
            // Legacy support: if status field doesn't exist, use old approvalStatus
            debugPrint('⚠️ Status field not found, using legacy approvalStatus...');
            if (!includePending) {
              fallbackQuery = fallbackQuery.where('approvalStatus', isEqualTo: 'approved');
            } else {
              fallbackQuery = fallbackQuery.where('approvalStatus', whereIn: ['approved', 'pending']);
            }
          }
          
          final snapshot = await fallbackQuery.limit(limit).get();
          debugPrint('✅ Fallback query succeeded, found ${snapshot.docs.length} decks');
          
          final decks = snapshot.docs.map((doc) {
            final data = _safeGetDocumentData(doc);
            if (data == null) {
              throw Exception('Document ${doc.id} has null data');
            }
            data['deckId'] = doc.id;
            return _convertDocumentData(data);
          }).toList();
          
          // Filter out hidden decks (client-side fallback)
          decks.removeWhere((deck) => deck['status'] == 'hidden' || deck['approvalStatus'] == 'rejected');
          
          // Sort by createdAt descending (client-side)
          decks.sort((a, b) {
            final aDate = a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime(1970);
            final bDate = b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime(1970);
            return bDate.compareTo(aDate);
          });
          
          return decks.take(limit).toList();
        } catch (fallbackError) {
          debugPrint('❌ Fallback query also failed: $fallbackError');
          // Don't throw - return empty list instead to prevent app crash
          debugPrint('⚠️ Returning empty list to prevent app crash');
          return [];
        }
      }
      
      // Re-throw other Firebase errors
      debugPrint('❌ Firebase error: ${firebaseError.code} - ${firebaseError.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in getPublicDecks: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Return empty list instead of throwing to prevent app crash
      debugPrint('⚠️ Returning empty list to prevent app crash');
      return [];
    }
  }

  /// Get all decks that user can see (public approved + user's own decks)
  Future<List<Map<String, dynamic>>> getAllVisibleDecks({
    String? userId,
    int limit = 50,
  }) async {
    try {
      debugPrint('🔍 Getting all visible decks for userId: $userId');
      
      final List<Map<String, dynamic>> allDecks = [];
      final Set<String> deckIds = {}; // To avoid duplicates
      
      // 1. Get public decks (include pending for user's own decks visibility)
      try {
        debugPrint('📚 Loading public decks (including pending)...');
        final publicDecks = await getPublicDecks(limit: limit, includePending: true);
        debugPrint('✅ Found ${publicDecks.length} public decks');
        
        for (var deck in publicDecks) {
          final deckId = deck['deckId'] as String;
          if (!deckIds.contains(deckId)) {
            deckIds.add(deckId);
            allDecks.add(deck);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error loading public decks: $e');
        // Continue even if public decks fail
      }
      
      // 2. Get user's own decks (if userId provided)
      if (userId != null && userId.isNotEmpty) {
        try {
          debugPrint('👤 Loading user decks...');
          final userDecks = await getDecksByAuthor(userId);
          debugPrint('✅ Found ${userDecks.length} user decks');
          
          for (var deck in userDecks) {
            final deckId = deck['deckId'] as String;
            if (!deckIds.contains(deckId)) {
              deckIds.add(deckId);
              allDecks.add(deck);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error loading user decks: $e');
          // Continue even if user decks fail
        }
      }
      
      // Sort by createdAt descending
      allDecks.sort((a, b) {
        final aDate = a['createdAt'] != null ? DateTime.parse(a['createdAt']) : DateTime(1970);
        final bDate = b['createdAt'] != null ? DateTime.parse(b['createdAt']) : DateTime(1970);
        return bDate.compareTo(aDate);
      });
      
      debugPrint('✅ Total visible decks: ${allDecks.length}');
      return allDecks;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in getAllVisibleDecks: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get all visible decks: $e');
    }
  }

  /// Update deck
  /// Update deck
  /// If isPublic changes from false to true, will notify all admins
  Future<void> updateDeck(String deckId, Map<String, dynamic> updates) async {
    try {
      // Check if isPublic is being changed to true
      bool shouldNotifyAdmins = false;
      if (updates.containsKey('isPublic') && updates['isPublic'] == true) {
        // Get current deck to check if it was previously false
        try {
          final currentDeck = await getDeckById(deckId);
          if (currentDeck != null) {
            final currentIsPublic = currentDeck['isPublic'] == true;
            if (!currentIsPublic) {
              // Changing from false to true, notify admins
              shouldNotifyAdmins = true;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error checking current deck status: $e');
        }
      }

      final data = _prepareDataForFirestore(updates);
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _decksCollection.doc(deckId).update(data);

      // Notify admins if deck became public
      if (shouldNotifyAdmins) {
        try {
          final deckData = await getDeckById(deckId);
          if (deckData != null) {
            await _notifyAdminsAboutNewPublicDeck(deckId, deckData);
          }
        } catch (e) {
          // Don't fail update if notification fails
          debugPrint('⚠️ Error notifying admins about deck becoming public: $e');
        }
      }
    } catch (e) {
      throw Exception('Failed to update deck: $e');
    }
  }

  /// Delete deck
  Future<void> deleteDeck(String deckId) async {
    try {
      // Delete all flashcards in this deck
      final flashcardsSnapshot = await _flashcardsCollection
          .where('deckId', isEqualTo: deckId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in flashcardsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete deck
      batch.delete(_decksCollection.doc(deckId));
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to delete deck: $e');
    }
  }

  /// Increment deck view count
  Future<void> incrementDeckViewCount(String deckId) async {
    try {
      await _decksCollection.doc(deckId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      throw Exception('Failed to increment view count: $e');
    }
  }

  // ==================== Flashcards Collection ====================

  /// Create flashcard
  Future<String> createFlashcard(Map<String, dynamic> flashcardData) async {
    try {
      final deckId = flashcardData['deckId'] as String?;
      if (deckId == null || deckId.isEmpty) {
        throw Exception('Deck ID is required');
      }
      
      // Verify deck exists and user has permission
      final deckData = await getDeckById(deckId);
      if (deckData == null) {
        throw Exception('Deck not found');
      }
      
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }
      
      // Check if user is the owner of the deck
      if (deckData['authorId'] != userId) {
        throw Exception('You can only add flashcards to your own decks');
      }
      
      // Auto-calculate order if not provided
      if (!flashcardData.containsKey('order') || flashcardData['order'] == null) {
        try {
          // Get current flashcards count to determine next order
          final existingFlashcards = await getFlashcardsByDeck(deckId);
          final nextOrder = existingFlashcards.length;
          flashcardData['order'] = nextOrder;
          debugPrint('📊 Calculated order: $nextOrder for deck: $deckId');
        } catch (e) {
          debugPrint('⚠️ Warning: Failed to get existing flashcards, using order 0: $e');
          // If query fails (e.g., no index), use 0 as default
          flashcardData['order'] = 0;
        }
      }
      
      final data = _prepareDataForFirestore(flashcardData);
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['isActive'] = true;
      
      // Ensure order is set
      if (!data.containsKey('order')) {
        data['order'] = 0;
      }

      debugPrint('💾 Creating flashcard with data: ${data.keys.toList()}');
      final docRef = await _flashcardsCollection.add(data);
      debugPrint('✅ Flashcard created with ID: ${docRef.id}');
      
      // Increment flashcard count in deck
      try {
        await _decksCollection.doc(deckId).update({
          'flashcardCount': FieldValue.increment(1),
        });
        debugPrint('✅ Incremented flashcard count for deck: $deckId');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to increment flashcard count: $e');
        // Don't throw - flashcard is already created
      }

      return docRef.id;
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating flashcard: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to create flashcard: $e');
    }
  }

  /// Get flashcard by ID
  Future<Map<String, dynamic>?> getFlashcardById(String flashcardId) async {
    try {
      final doc = await _flashcardsCollection.doc(flashcardId).get();
      if (!doc.exists) {
        return null;
      }
      final data = _safeGetDocumentData(doc);
      if (data == null) {
        return null;
      }
      data['flashcardId'] = doc.id;
      return _convertDocumentData(data);
    } catch (e) {
      throw Exception('Failed to get flashcard: $e');
    }
  }

  /// Batch create flashcards (tối đa 500 per batch - Firestore limit)
  /// Returns list of created flashcard IDs
  Future<List<String>> batchCreateFlashcards({
    required String deckId,
    required List<Map<String, dynamic>> flashcardsData,
  }) async {
    try {
      if (flashcardsData.isEmpty) {
        throw Exception('Flashcards data is empty');
      }
      
      // Verify deck exists and user has permission
      final deckData = await getDeckById(deckId);
      if (deckData == null) {
        throw Exception('Deck not found');
      }
      
      final userId = currentUserId;
      if (userId == null) {
        throw Exception('User must be authenticated');
      }
      
      // Check if user is the owner of the deck
      if (deckData['authorId'] != userId) {
        throw Exception('You can only add flashcards to your own decks');
      }
      
      // Get current order
      int startOrder;
      try {
        final existingFlashcards = await getFlashcardsByDeck(deckId);
        startOrder = existingFlashcards.length;
        debugPrint('📊 Starting order: $startOrder for deck: $deckId');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to get existing flashcards, using order 0: $e');
        startOrder = 0;
      }
      
      // Firestore batch limit: 500 operations per batch
      const batchLimit = 500;
      final createdIds = <String>[];
      
      // Process in batches
      for (int i = 0; i < flashcardsData.length; i += batchLimit) {
        final batch = _firestore.batch();
        final endIndex = (i + batchLimit < flashcardsData.length) 
            ? i + batchLimit 
            : flashcardsData.length;
        
        debugPrint('📦 Processing batch ${i ~/ batchLimit + 1}: flashcards $i to ${endIndex - 1}');
        
        for (int j = i; j < endIndex; j++) {
          final cardData = Map<String, dynamic>.from(flashcardsData[j]);
          
          // Prepare data
          final data = _prepareDataForFirestore(cardData);
          data['deckId'] = deckId;
          data['order'] = startOrder + j;
          data['createdAt'] = FieldValue.serverTimestamp();
          data['updatedAt'] = FieldValue.serverTimestamp();
          data['isActive'] = true;
          
          // Ensure required fields
          if (!data.containsKey('tags') || data['tags'] == null) {
            data['tags'] = <String>[];
          }
          
          // Create document reference
          final docRef = _flashcardsCollection.doc();
          batch.set(docRef, data);
          createdIds.add(docRef.id);
        }
        
        // Commit batch
        await batch.commit();
        debugPrint('✅ Batch ${i ~/ batchLimit + 1} committed: ${endIndex - i} flashcards');
      }
      
      // Update deck flashcard count (single update)
      try {
        await _decksCollection.doc(deckId).update({
          'flashcardCount': FieldValue.increment(flashcardsData.length),
        });
        debugPrint('✅ Updated flashcard count for deck: $deckId (+${flashcardsData.length})');
      } catch (e) {
        debugPrint('⚠️ Warning: Failed to update flashcard count: $e');
        // Don't throw - flashcards are already created
      }
      
      debugPrint('✅ Total created: ${createdIds.length} flashcards');
      return createdIds;
    } catch (e, stackTrace) {
      debugPrint('❌ Error batch creating flashcards: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to batch create flashcards: $e');
    }
  }

  /// Get flashcards by deck ID
  Future<List<Map<String, dynamic>>> getFlashcardsByDeck(String deckId) async {
    try {
      // Try to get flashcards with orderBy first (requires index)
      try {
        final snapshot = await _flashcardsCollection
            .where('deckId', isEqualTo: deckId)
            .where('isActive', isEqualTo: true)
            .orderBy('order')
            .get();
        
        return snapshot.docs.map((doc) {
          final data = _safeGetDocumentData(doc);
          if (data == null) {
            throw Exception('Flashcard document ${doc.id} has null data');
          }
          data['flashcardId'] = doc.id;
          return _convertDocumentData(data);
        }).toList();
      } catch (e) {
        // If orderBy fails (e.g., missing index), try without orderBy
        debugPrint('⚠️ Warning: orderBy query failed, trying without orderBy: $e');
        final snapshot = await _flashcardsCollection
            .where('deckId', isEqualTo: deckId)
            .where('isActive', isEqualTo: true)
            .get();
        
        final flashcards = snapshot.docs.map((doc) {
          final data = _safeGetDocumentData(doc);
          if (data == null) {
            throw Exception('Flashcard document ${doc.id} has null data');
          }
          data['flashcardId'] = doc.id;
          return _convertDocumentData(data);
        }).toList();
        
        // Sort manually by order field if available
        flashcards.sort((a, b) {
          final orderA = a['order'] ?? 0;
          final orderB = b['order'] ?? 0;
          return (orderA as num).compareTo(orderB as num);
        });
        
        return flashcards;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error getting flashcards by deck: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to get flashcards by deck: $e');
    }
  }

  /// Update flashcard
  Future<void> updateFlashcard(String flashcardId, Map<String, dynamic> updates) async {
    try {
      final data = _prepareDataForFirestore(updates);
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _flashcardsCollection.doc(flashcardId).update(data);
    } catch (e) {
      throw Exception('Failed to update flashcard: $e');
    }
  }

  /// Delete flashcard
  Future<void> deleteFlashcard(String flashcardId, String deckId) async {
    try {
      // Soft delete: set isActive to false
      await _flashcardsCollection.doc(flashcardId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Decrement flashcard count in deck
      await _decksCollection.doc(deckId).update({
        'flashcardCount': FieldValue.increment(-1),
      });
    } catch (e) {
      throw Exception('Failed to delete flashcard: $e');
    }
  }

  // ==================== Deck Favorites Collection ====================

  /// Toggle favorite deck
  Future<bool> toggleFavoriteDeck(String userId, String deckId) async {
    try {
      final favoriteId = '${userId}_$deckId';
      final favoriteDoc = await _deckFavoritesCollection.doc(favoriteId).get();

      if (favoriteDoc.exists) {
        // Remove favorite
        await _deckFavoritesCollection.doc(favoriteId).delete();
        await _decksCollection.doc(deckId).update({
          'favoriteCount': FieldValue.increment(-1),
        });
        return false;
      } else {
        // Add favorite
        await _deckFavoritesCollection.doc(favoriteId).set({
          'userId': userId,
          'deckId': deckId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        await _decksCollection.doc(deckId).update({
          'favoriteCount': FieldValue.increment(1),
        });
        return true;
      }
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }

  /// Check if deck is favorited by user
  Future<bool> isDeckFavorited(String userId, String deckId) async {
    try {
      final favoriteId = '${userId}_$deckId';
      final doc = await _deckFavoritesCollection.doc(favoriteId).get();
      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check favorite status: $e');
    }
  }

  /// Get user's favorite decks
  Future<List<Map<String, dynamic>>> getUserFavoriteDecks(String userId) async {
    try {
      final snapshot = await _deckFavoritesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final deckIds = snapshot.docs
          .map((doc) {
            final data = _safeGetDocumentData(doc);
            return data?['deckId'] as String?;
          })
          .whereType<String>()
          .toList();
      
      if (deckIds.isEmpty) {
        return [];
      }

      final decks = <Map<String, dynamic>>[];
      for (var deckId in deckIds) {
        final deck = await getDeckById(deckId);
        if (deck != null) {
          decks.add(deck);
        }
      }

      return decks;
    } catch (e) {
      throw Exception('Failed to get favorite decks: $e');
    }
  }

  // ==================== User Deck Progress Collection ====================

  /// Create or update user deck progress
  Future<void> updateUserDeckProgress({
    required String userId,
    required String deckId,
    required Map<String, dynamic> progressData,
  }) async {
    try {
      final progressId = '${userId}_$deckId';
      final data = _prepareDataForFirestore(progressData);
      data['userId'] = userId;
      data['deckId'] = deckId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (!data.containsKey('createdAt')) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _userDeckProgressCollection.doc(progressId).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update deck progress: $e');
    }
  }

  /// Get user deck progress for a specific deck
  Future<Map<String, dynamic>?> getUserDeckProgress(String userId, String deckId) async {
    try {
      final progressId = '${userId}_$deckId';
      final doc = await _userDeckProgressCollection.doc(progressId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = _safeGetDocumentData(doc);
      if (data == null) {
        return null;
      }
      data['progressId'] = doc.id;
      return _convertDocumentData(data);
    } catch (e) {
      throw Exception('Failed to get deck progress: $e');
    }
  }

  /// Get all deck progress for a user
  Future<List<Map<String, dynamic>>> getAllUserDeckProgress(String userId) async {
    try {
      debugPrint('🔍 Querying deck progress for userId: $userId');
      
      // Try with orderBy first
      try {
        final snapshot = await _userDeckProgressCollection
            .where('userId', isEqualTo: userId)
            .orderBy('lastStudyDate', descending: true)
            .get();

        debugPrint('✅ Found ${snapshot.docs.length} deck progress records with orderBy');
        
        return snapshot.docs.map((doc) {
          final data = _safeGetDocumentData(doc);
          if (data == null) {
            throw Exception('Progress document ${doc.id} has null data');
          }
          data['progressId'] = doc.id;
          final converted = _convertDocumentData(data);
          debugPrint('   📝 Progress: deckId=${converted['deckId']}, studiedFlashcards=${converted['studiedFlashcards']}');
          return converted;
        }).toList();
      } on FirebaseException catch (e) {
        // If index is missing or lastStudyDate is null, try without orderBy
        if (e.code == 'failed-precondition' || e.code == 'invalid-argument') {
          debugPrint('⚠️ Index issue or null lastStudyDate, trying without orderBy...');
          final snapshot = await _userDeckProgressCollection
              .where('userId', isEqualTo: userId)
              .get();

          debugPrint('✅ Found ${snapshot.docs.length} deck progress records without orderBy');

          final results = snapshot.docs.map((doc) {
            final data = _safeGetDocumentData(doc);
            if (data == null) {
              throw Exception('Progress document ${doc.id} has null data');
            }
            data['progressId'] = doc.id;
            final converted = _convertDocumentData(data);
            debugPrint('   📝 Progress: deckId=${converted['deckId']}, studiedFlashcards=${converted['studiedFlashcards']}');
            return converted;
          }).toList();

          // Sort by lastStudyDate descending (client-side) if available
          results.sort((a, b) {
            final aDateStr = a['lastStudyDate'] as String?;
            final bDateStr = b['lastStudyDate'] as String?;
            
            if (aDateStr == null && bDateStr == null) return 0;
            if (aDateStr == null) return 1;
            if (bDateStr == null) return -1;
            
            try {
              final aDate = DateTime.parse(aDateStr);
              final bDate = DateTime.parse(bDateStr);
              return bDate.compareTo(aDate);
            } catch (e) {
              return 0;
            }
          });

          return results;
        } else {
          debugPrint('❌ Firebase error: ${e.code} - ${e.message}');
          throw Exception('Failed to get deck progress: ${e.message}');
        }
      } catch (innerError) {
        debugPrint('❌ Error in getAllUserDeckProgress: $innerError');
        throw Exception('Failed to get user deck progress: $innerError');
      }
    } catch (e) {
      debugPrint('❌ Error getting all user deck progress: $e');
      throw Exception('Failed to get user deck progress: $e');
    }
  }

  // ==================== User Flashcard Progress Collection ====================

  /// Create or update user flashcard progress
  Future<void> updateUserFlashcardProgress({
    required String userId,
    required String flashcardId,
    required String deckId,
    required Map<String, dynamic> progressData,
  }) async {
    try {
      final progressId = '${userId}_$flashcardId';
      final data = _prepareDataForFirestore(progressData);
      data['userId'] = userId;
      data['flashcardId'] = flashcardId;
      data['deckId'] = deckId;
      data['updatedAt'] = FieldValue.serverTimestamp();

      if (!data.containsKey('createdAt')) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      await _userFlashcardProgressCollection.doc(progressId).set(data, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update flashcard progress: $e');
    }
  }

  /// Get user flashcard progress
  Future<Map<String, dynamic>?> getUserFlashcardProgress(String userId, String flashcardId) async {
    try {
      final progressId = '${userId}_$flashcardId';
      final doc = await _userFlashcardProgressCollection.doc(progressId).get();
      
      if (!doc.exists) {
        return null;
      }

      final data = _safeGetDocumentData(doc);
      if (data == null) {
        return null;
      }
      data['progressId'] = doc.id;
      return _convertDocumentData(data);
    } catch (e) {
      throw Exception('Failed to get flashcard progress: $e');
    }
  }

  /// Get all user flashcard progress
  Future<List<Map<String, dynamic>>> getAllUserFlashcardProgress(String userId, {int limit = 1000}) async {
    try {
      final snapshot = await _userFlashcardProgressCollection
          .where('userId', isEqualTo: userId)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('User flashcard progress document ${doc.id} has null data');
        }
        data['progressId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting all user flashcard progress: $e');
      throw Exception('Failed to get all user flashcard progress: $e');
    }
  }

  // ==================== Reports Collection ====================

  /// Create report
  Future<String> createReport(Map<String, dynamic> reportData) async {
    try {
      final data = _prepareDataForFirestore(reportData);
      data['status'] = 'pending';
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      final docRef = await _reportsCollection.add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  /// Get all reports (admin)
  Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      final snapshot = await _reportsCollection
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Report document ${doc.id} has null data');
        }
        data['reportId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get all reports: $e');
    }
  }

  /// Get report by ID
  Future<Map<String, dynamic>?> getReportById(String reportId) async {
    try {
      final doc = await _reportsCollection.doc(reportId).get();
      if (!doc.exists) {
        return null;
      }
      final data = _safeGetDocumentData(doc);
      if (data == null) {
        return null;
      }
      data['reportId'] = doc.id;
      return _convertDocumentData(data);
    } catch (e) {
      throw Exception('Failed to get report: $e');
    }
  }

  /// Update report status
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? adminNotes,
    String? resolvedBy,
  }) async {
    try {
      // Get report data first to notify reporter
      final reportData = await getReportById(reportId);
      if (reportData == null) {
        throw Exception('Report not found');
      }

      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (adminNotes != null) {
        updates['adminNotes'] = adminNotes;
      }

      if (resolvedBy != null) {
        updates['resolvedBy'] = resolvedBy;
        updates['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await _reportsCollection.doc(reportId).update(updates);

      // Notify reporter if resolved or rejected
      if (status == 'resolved' || status == 'rejected') {
        final reporterId = reportData['reporterId'] as String?;
        final deckId = reportData['deckId'] as String?;
        
        if (reporterId != null && deckId != null) {
          try {
            // Get deck name
            final deckData = await getDeckById(deckId);
            final deckName = deckData?['name'] as String? ?? 'Unnamed Deck';
            
            await _notifyUserAboutReportResolution(
              reporterId: reporterId,
              reportId: reportId,
              deckId: deckId,
              deckName: deckName,
              status: status,
              adminNotes: adminNotes,
            );
          } catch (notifyError) {
            // Don't fail status update if notification fails
            debugPrint('⚠️ Error notifying user about report resolution: $notifyError');
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }

  // ==================== Study Sessions Collection ====================

  /// Create study session
  Future<String> createStudySession(Map<String, dynamic> sessionData) async {
    try {
      final data = _prepareDataForFirestore(sessionData);
      data['createdAt'] = FieldValue.serverTimestamp();

      final docRef = await _studySessionsCollection.add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create study session: $e');
    }
  }

  /// Get user's study sessions
  Future<List<Map<String, dynamic>>> getUserStudySessions(String userId) async {
    try {
      final snapshot = await _studySessionsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('startTime', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Study session document ${doc.id} has null data');
        }
        data['sessionId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      throw Exception('Failed to get study sessions: $e');
    }
  }

  // ==================== Search Methods ====================

  /// Normalize Vietnamese text for fuzzy search (remove diacritics)
  String _normalizeVietnamese(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a')
        .replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e')
        .replaceAll(RegExp(r'[ìíịỉĩ]'), 'i')
        .replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o')
        .replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u')
        .replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y')
        .replaceAll(RegExp(r'[đ]'), 'd');
  }

  /// Check if text matches query using fuzzy search (gần đúng)
  /// Supports:
  /// - Partial match (contains)
  /// - Word-by-word match (each word in query matches)
  /// - Vietnamese diacritics insensitive
  bool _fuzzyMatch(String text, String query) {
    if (text.isEmpty || query.isEmpty) return false;
    
    // Normalize both text and query
    final normalizedText = _normalizeVietnamese(text);
    final normalizedQuery = _normalizeVietnamese(query);
    
    // 1. Exact match (after normalization)
    if (normalizedText.contains(normalizedQuery)) {
      return true;
    }
    
    // 2. Word-by-word match: check if all words in query appear in text
    final queryWords = normalizedQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (queryWords.isEmpty) return false;
    
    // All words must be found in text
    bool allWordsFound = true;
    for (final word in queryWords) {
      if (!normalizedText.contains(word)) {
        allWordsFound = false;
        break;
      }
    }
    
    return allWordsFound;
  }

  /// Search decks by name using fuzzy search (tìm kiếm gần đúng)
  /// Includes both public approved decks and user's own decks
  /// Supports:
  /// - Partial match (contains)
  /// - Word-by-word match
  /// - Vietnamese diacritics insensitive
  Future<List<Map<String, dynamic>>> searchDecks(String query) async {
    try {
      debugPrint('🔍 Searching decks with query: "$query" (fuzzy search)');
      final results = <Map<String, dynamic>>[];
      final Set<String> deckIds = {}; // To avoid duplicates
      
      final currentUserId = _auth.currentUser?.uid;
      
      // 1. Search public decks (post-moderation: not hidden)
      try {
        debugPrint('📚 Searching public decks (excluding hidden)...');
        final publicSnapshot = await _decksCollection
            .where('isPublic', isEqualTo: true)
            .where('status', isNotEqualTo: 'hidden')
            .get();
        
        debugPrint('✅ Found ${publicSnapshot.docs.length} public decks');
        
        for (var doc in publicSnapshot.docs) {
          final data = _safeGetDocumentData(doc);
          if (data == null) continue;
          
          final name = data['name'] as String? ?? '';
          final description = data['description'] as String? ?? '';
          final authorName = data['authorName'] as String? ?? '';

          // Fuzzy match: check name, description, and author name
          if (_fuzzyMatch(name, query) || 
              _fuzzyMatch(description, query) ||
              _fuzzyMatch(authorName, query)) {
            final deckId = doc.id;
            if (!deckIds.contains(deckId)) {
              deckIds.add(deckId);
              data['deckId'] = deckId;
              results.add(_convertDocumentData(data));
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error searching public decks: $e');
      }
      
      // 2. Search user's own decks (if logged in)
      if (currentUserId != null) {
        try {
          debugPrint('👤 Searching user decks for userId: $currentUserId');
          final userDecksSnapshot = await _decksCollection
              .where('authorId', isEqualTo: currentUserId)
              .get();
          
          debugPrint('✅ Found ${userDecksSnapshot.docs.length} user decks');
          
          for (var doc in userDecksSnapshot.docs) {
            final data = _safeGetDocumentData(doc);
            if (data == null) continue;
            
            final name = data['name'] as String? ?? '';
            final description = data['description'] as String? ?? '';
            final authorName = data['authorName'] as String? ?? '';

            // Fuzzy match: check name, description, and author name
            if (_fuzzyMatch(name, query) || 
                _fuzzyMatch(description, query) ||
                _fuzzyMatch(authorName, query)) {
              final deckId = doc.id;
              if (!deckIds.contains(deckId)) {
                deckIds.add(deckId);
                data['deckId'] = deckId;
                results.add(_convertDocumentData(data));
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error searching user decks: $e');
        }
      }
      
      debugPrint('✅ Total search results: ${results.length} decks');
      return results;
    } catch (e, stackTrace) {
      debugPrint('❌ Error in searchDecks: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      throw Exception('Failed to search decks: $e');
    }
  }


  /// Search flashcards by front or back content using fuzzy search (tìm kiếm gần đúng)
  /// Supports:
  /// - Partial match (contains)
  /// - Word-by-word match
  /// - Vietnamese diacritics insensitive
  Future<List<Map<String, dynamic>>> searchFlashcards(String query, {String? deckId}) async {
    try {
      debugPrint('🔍 Searching flashcards with query: "$query" (fuzzy search)');
      Query queryRef;
      
      if (deckId != null) {
        // Search within a specific deck
        queryRef = _flashcardsCollection.where('deckId', isEqualTo: deckId);
      } else {
        // Search all flashcards (limited to active ones)
        queryRef = _flashcardsCollection.where('isActive', isEqualTo: true);
      }

      final snapshot = await queryRef.get();
      final results = <Map<String, dynamic>>[];

      debugPrint('✅ Found ${snapshot.docs.length} flashcards to search');

      for (var doc in snapshot.docs) {
        final data = _safeGetDocumentData(doc);
        if (data == null) continue;
        
        final front = data['front'] as String? ?? '';
        final back = data['back'] as String? ?? '';
        final tags = (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

        // Fuzzy match: check front, back, and tags
        bool matches = _fuzzyMatch(front, query) || _fuzzyMatch(back, query);
        
        // Also check tags
        if (!matches) {
          for (final tag in tags) {
            if (_fuzzyMatch(tag, query)) {
              matches = true;
              break;
            }
          }
        }

        if (matches) {
          data['flashcardId'] = doc.id;
          results.add(_convertDocumentData(data));
        }
      }

      debugPrint('✅ Found ${results.length} matching flashcards');
      return results;
    } catch (e) {
      debugPrint('❌ Error searching flashcards: $e');
      throw Exception('Failed to search flashcards: $e');
    }
  }

  // ==================== Notifications Collection ====================

  /// Create a notification
  Future<String> createNotification({
    required String userId,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationData = {
        'userId': userId,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _notificationsCollection.add(notificationData);
      debugPrint('✅ Created notification: ${docRef.id} for user: $userId');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      throw Exception('Failed to create notification: $e');
    }
  }

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getUserNotifications(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Notification document ${doc.id} has null data');
        }
        data['notificationId'] = doc.id;
        return _convertDocumentData(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      throw Exception('Failed to get notifications: $e');
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationsCount(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Marked notification as read: $notificationId');
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      throw Exception('Failed to mark notification as read: $e');
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Marked all notifications as read for user: $userId');
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
      throw Exception('Failed to mark all notifications as read: $e');
    }
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
      debugPrint('✅ Deleted notification: $notificationId');
    } catch (e) {
      debugPrint('❌ Error deleting notification: $e');
      throw Exception('Failed to delete notification: $e');
    }
  }

  // ==================== Notification Helper Functions ====================

  /// Notify admins about new report
  Future<void> _notifyAdminsAboutNewReport({
    required String reportId,
    required String deckId,
    required String deckName,
    required String reporterId,
    required String reporterName,
  }) async {
    try {
      final adminUsers = await _getAdminUsers();
      if (adminUsers.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return;
      }

      final batch = _firestore.batch();
      for (var admin in adminUsers) {
        final adminId = admin['userId'] as String;
        final notificationRef = _notificationsCollection.doc();
        
        batch.set(notificationRef, {
          'userId': adminId,
          'type': 'report_created',
          'title': 'Có báo cáo mới',
          'message': 'Deck "$deckName" đã bị báo cáo bởi $reporterName',
          'data': {
            'reportId': reportId,
            'deckId': deckId,
            'reporterId': reporterId,
            'reporterName': reporterName,
          },
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ Notified ${adminUsers.length} admin(s) about new report: $reportId');
    } catch (e) {
      debugPrint('❌ Error notifying admins about report: $e');
      // Don't throw - notification failure shouldn't break the main operation
    }
  }

  /// Notify user about report resolution
  Future<void> _notifyUserAboutReportResolution({
    required String reporterId,
    required String reportId,
    required String deckId,
    required String deckName,
    required String status, // 'resolved' or 'rejected'
    String? adminNotes,
  }) async {
    try {
      final type = status == 'resolved' ? 'report_resolved' : 'report_rejected';
      final title = status == 'resolved' 
          ? 'Báo cáo đã được xử lý' 
          : 'Báo cáo đã bị từ chối';
      final message = status == 'resolved'
          ? 'Báo cáo của bạn về deck "$deckName" đã được admin xử lý'
          : 'Báo cáo của bạn về deck "$deckName" đã bị từ chối';

      await createNotification(
        userId: reporterId,
        type: type,
        title: title,
        message: message,
        data: {
          'reportId': reportId,
          'deckId': deckId,
          if (adminNotes != null) 'adminNotes': adminNotes,
        },
      );
      debugPrint('✅ Notified user $reporterId about report resolution: $status');
    } catch (e) {
      debugPrint('❌ Error notifying user about report: $e');
      // Don't throw - notification failure shouldn't break the main operation
    }
  }

  /// Notify author about deck status change
  Future<void> _notifyAuthorAboutDeckStatus({
    required String authorId,
    required String deckId,
    required String deckName,
    required String status, // 'hidden' or 'restored'
    String? reason,
  }) async {
    try {
      final type = status == 'hidden' ? 'deck_hidden' : 'deck_restored';
      final title = status == 'hidden'
          ? 'Deck của bạn đã bị ẩn'
          : 'Deck của bạn đã được khôi phục';
      final message = status == 'hidden'
          ? 'Deck "$deckName" của bạn đã bị admin ẩn.${reason != null ? " Lý do: $reason" : ""}'
          : 'Deck "$deckName" của bạn đã được admin khôi phục';

      await createNotification(
        userId: authorId,
        type: type,
        title: title,
        message: message,
        data: {
          'deckId': deckId,
          if (reason != null) 'reason': reason,
        },
      );
      debugPrint('✅ Notified author $authorId about deck status: $status');
    } catch (e) {
      debugPrint('❌ Error notifying author: $e');
      // Don't throw - notification failure shouldn't break the main operation
    }
  }

  /// Notify user about account status change
  Future<void> _notifyUserAboutAccountStatus({
    required String userId,
    required bool isBlocked,
  }) async {
    try {
      final type = isBlocked ? 'user_blocked' : 'user_unblocked';
      final title = isBlocked
          ? 'Tài khoản của bạn đã bị khóa'
          : 'Tài khoản của bạn đã được mở khóa';
      final message = isBlocked
          ? 'Tài khoản của bạn đã bị admin khóa. Vui lòng liên hệ hỗ trợ.'
          : 'Tài khoản của bạn đã được admin mở khóa. Bạn có thể sử dụng lại dịch vụ.';

      await createNotification(
        userId: userId,
        type: type,
        title: title,
        message: message,
        data: {},
      );
      debugPrint('✅ Notified user $userId about account status: ${isBlocked ? "blocked" : "unblocked"}');
    } catch (e) {
      debugPrint('❌ Error notifying user about account status: $e');
      // Don't throw - notification failure shouldn't break the main operation
    }
  }

  // ==================== Admin Operations ====================

  /// Search users (fuzzy search)
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final allUsers = await getAllUsers();
      
      return allUsers.where((user) {
        final name = user['name'] as String? ?? '';
        final email = user['email'] as String? ?? '';
        return _fuzzyMatch(name, query) || _fuzzyMatch(email, query);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error searching users: $e');
      throw Exception('Failed to search users: $e');
    }
  }

  /// Toggle block/unblock user
  Future<void> toggleBlockUser(String userId, bool isBlocked) async {
    try {
      await _usersCollection.doc(userId).update({
        'isBlocked': isBlocked,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify user about account status change
      try {
        await _notifyUserAboutAccountStatus(
          userId: userId,
          isBlocked: isBlocked,
        );
      } catch (notifyError) {
        // Don't fail block operation if notification fails
        debugPrint('⚠️ Error notifying user about account status: $notifyError');
      }

      debugPrint('✅ User $userId ${isBlocked ? "blocked" : "unblocked"}');
    } catch (e) {
      debugPrint('❌ Error toggling block user: $e');
      throw Exception('Failed to toggle block user: $e');
    }
  }

  /// Reset user password (Note: Requires Cloud Functions or Admin SDK)
  /// This is a placeholder - actual implementation should use Cloud Functions
  Future<void> resetUserPassword(String userId, String newPassword) async {
    try {
      // TODO: Implement via Cloud Functions
      // For now, just log that this should be done via Cloud Functions
      debugPrint('⚠️ resetUserPassword should be implemented via Cloud Functions');
      throw Exception('Password reset must be done via Cloud Functions or Admin SDK');
    } catch (e) {
      debugPrint('❌ Error resetting password: $e');
      throw Exception('Failed to reset password: $e');
    }
  }

  /// Delete user and all related data
  Future<void> deleteUser(String userId) async {
    try {
      final batch = _firestore.batch();
      
      // Delete user document
      batch.delete(_usersCollection.doc(userId));
      
      // Delete user's decks
      final userDecks = await _decksCollection
          .where('authorId', isEqualTo: userId)
          .get();
      for (var doc in userDecks.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's flashcards
      final userFlashcards = await _flashcardsCollection
          .where('authorId', isEqualTo: userId)
          .get();
      for (var doc in userFlashcards.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user progress
      final deckProgress = await _userDeckProgressCollection
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in deckProgress.docs) {
        batch.delete(doc.reference);
      }
      
      final flashcardProgress = await _userFlashcardProgressCollection
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in flashcardProgress.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's favorites
      final favorites = await _deckFavoritesCollection
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in favorites.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's study sessions
      final studySessions = await _studySessionsCollection
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in studySessions.docs) {
        batch.delete(doc.reference);
      }
      
      // Delete user's notifications
      final notifications = await _notificationsCollection
          .where('userId', isEqualTo: userId)
          .get();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('✅ Deleted user and all related data: $userId');
    } catch (e) {
      debugPrint('❌ Error deleting user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Get user statistics
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      // Get user's decks
      final userDecks = await getDecksByAuthor(userId);
      
      // Get user's flashcards count
      int totalFlashcards = 0;
      for (var deck in userDecks) {
        totalFlashcards += (deck['flashcardCount'] as num?)?.toInt() ?? 0;
      }
      
      // Get user's deck progress
      final deckProgress = await getAllUserDeckProgress(userId);
      final decksStudied = deckProgress.length;
      
      // Get user's flashcard progress
      final flashcardProgress = await getAllUserFlashcardProgress(userId);
      final flashcardsStudied = flashcardProgress.length;
      
      // Get user's study sessions
      final studySessions = await getUserStudySessions(userId);
      
      // Get user's join date
      final userDoc = await _usersCollection.doc(userId).get();
      final userData = _safeGetDocumentData(userDoc);
      final createdAt = userData?['createdAt'];
      
      return {
        'totalDecks': userDecks.length,
        'totalFlashcards': totalFlashcards,
        'decksStudied': decksStudied,
        'flashcardsStudied': flashcardsStudied,
        'studySessions': studySessions.length,
        'joinDate': createdAt,
      };
    } catch (e) {
      debugPrint('❌ Error getting user statistics: $e');
      throw Exception('Failed to get user statistics: $e');
    }
  }

  /// Get all decks for admin (public decks grouped by user)
  /// Admin quản lý các deck công khai theo user
  Future<List<Map<String, dynamic>>> getAllDecksForAdmin({int limit = 100}) async {
    try {
      // Admin quản lý các deck công khai của tất cả user
      return await getPublicDecks(limit: limit);
    } catch (e) {
      debugPrint('❌ Error getting all decks for admin: $e');
      throw Exception('Failed to get all decks for admin: $e');
    }
  }

  /// Report deck (user reports inappropriate content)
  /// Changes deck status to 'reported' and creates a report
  Future<void> reportDeck(String deckId, String reporterId, String reporterName, String reason) async {
    try {
      // Get deck info for notification
      final deckData = await getDeckById(deckId);
      final deckName = deckData?['name'] as String? ?? 'Unnamed Deck';
      
      // Update deck status to 'reported'
      await _decksCollection.doc(deckId).update({
        'status': 'reported',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Create report
      final reportRef = await _reportsCollection.add({
        'reporterId': reporterId,
        'reporterName': reporterName,
        'reportType': 'deck',
        'content': reason,
        'deckId': deckId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      final reportId = reportRef.id;
      
      // Notify admins about new report
      try {
        await _notifyAdminsAboutNewReport(
          reportId: reportId,
          deckId: deckId,
          deckName: deckName,
          reporterId: reporterId,
          reporterName: reporterName,
        );
      } catch (notifyError) {
        // Don't fail report creation if notification fails
        debugPrint('⚠️ Error notifying admins about report: $notifyError');
      }
      
      debugPrint('✅ Deck reported: $deckId');
    } catch (e) {
      debugPrint('❌ Error reporting deck: $e');
      throw Exception('Failed to report deck: $e');
    }
  }

  /// Hide deck (admin hides reported deck)
  /// Changes deck status to 'hidden' so it's not visible to users
  Future<void> hideDeck(String deckId, String reason) async {
    try {
      // Get deck data first to notify author
      final deckData = await getDeckById(deckId);
      if (deckData == null) {
        throw Exception('Deck not found');
      }

      final authorId = deckData['authorId'] as String?;
      final deckName = deckData['name'] as String? ?? 'Unnamed Deck';

      await _decksCollection.doc(deckId).update({
        'status': 'hidden',
        'hiddenReason': reason,
        'hiddenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify author
      if (authorId != null) {
        try {
          await _notifyAuthorAboutDeckStatus(
            authorId: authorId,
            deckId: deckId,
            deckName: deckName,
            status: 'hidden',
            reason: reason,
          );
        } catch (notifyError) {
          // Don't fail hide operation if notification fails
          debugPrint('⚠️ Error notifying author about deck hidden: $notifyError');
        }
      }

      debugPrint('✅ Deck hidden: $deckId');
    } catch (e) {
      debugPrint('❌ Error hiding deck: $e');
      throw Exception('Failed to hide deck: $e');
    }
  }

  /// Restore deck (admin restores hidden deck)
  /// Changes deck status back to 'public' or 'private' based on isPublic
  Future<void> restoreDeck(String deckId) async {
    try {
      final deckDoc = await _decksCollection.doc(deckId).get();
      final deckData = _safeGetDocumentData(deckDoc);
      if (deckData == null) {
        throw Exception('Deck not found');
      }
      
      final authorId = deckData['authorId'] as String?;
      final deckName = deckData['name'] as String? ?? 'Unnamed Deck';
      final isPublic = deckData['isPublic'] == true;
      
      await _decksCollection.doc(deckId).update({
        'status': isPublic ? 'public' : 'private',
        'hiddenReason': FieldValue.delete(),
        'hiddenAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Notify author
      if (authorId != null) {
        try {
          await _notifyAuthorAboutDeckStatus(
            authorId: authorId,
            deckId: deckId,
            deckName: deckName,
            status: 'restored',
          );
        } catch (notifyError) {
          // Don't fail restore operation if notification fails
          debugPrint('⚠️ Error notifying author about deck restored: $notifyError');
        }
      }

      debugPrint('✅ Deck restored: $deckId');
    } catch (e) {
      debugPrint('❌ Error restoring deck: $e');
      throw Exception('Failed to restore deck: $e');
    }
  }

  /// Get reported decks (for admin)
  Future<List<Map<String, dynamic>>> getReportedDecks({int limit = 100}) async {
    try {
      // Admin can read all decks, so we query all and filter client-side
      // This avoids permission-denied errors with .where('status', isEqualTo: 'reported')
      debugPrint('📚 Querying all decks for admin (will filter reported/hidden client-side)...');
      Query query = _decksCollection
          .orderBy('updatedAt', descending: true)
          .limit(limit * 2); // Get more to filter client-side
      
      final snapshot = await query.get();
      debugPrint('✅ Got ${snapshot.docs.length} decks from query');
      
      // Filter to only reported and hidden decks (admin manages these)
      final decks = snapshot.docs.map((doc) {
        final data = _safeGetDocumentData(doc);
        if (data == null) {
          throw Exception('Deck document ${doc.id} has null data');
        }
        data['deckId'] = doc.id;
        return _convertDocumentData(data);
      }).where((deck) {
        final status = deck['status'] ?? deck['approvalStatus'] ?? '';
        return status == 'reported' || status == 'hidden';
      }).toList();
      
      debugPrint('✅ Filtered to ${decks.length} reported/hidden decks');
      
      // Sort by updatedAt descending (already sorted, but ensure)
      decks.sort((a, b) {
        final aDate = a['updatedAt'] != null ? DateTime.parse(a['updatedAt']) : DateTime(1970);
        final bDate = b['updatedAt'] != null ? DateTime.parse(b['updatedAt']) : DateTime(1970);
        return bDate.compareTo(aDate);
      });
      
      return decks.take(limit).toList();
    } on FirebaseException catch (firebaseError) {
      // If index is missing, try fallback query without orderBy
      if (firebaseError.code == 'failed-precondition' || 
          firebaseError.message?.contains('index') == true) {
        debugPrint('⚠️ Index not ready, trying fallback without orderBy...');
        try {
          final snapshot = await _decksCollection
              .limit(limit * 3) // Get more to filter client-side
              .get();
          
          final decks = snapshot.docs.map((doc) {
            final data = _safeGetDocumentData(doc);
            if (data == null) {
              throw Exception('Deck document ${doc.id} has null data');
            }
            data['deckId'] = doc.id;
            return _convertDocumentData(data);
          }).where((deck) {
            final status = deck['status'] ?? deck['approvalStatus'] ?? '';
            return status == 'reported' || status == 'hidden';
          }).toList();
          
          // Sort by updatedAt descending (client-side)
          decks.sort((a, b) {
            final aDate = a['updatedAt'] != null ? DateTime.parse(a['updatedAt']) : DateTime(1970);
            final bDate = b['updatedAt'] != null ? DateTime.parse(b['updatedAt']) : DateTime(1970);
            return bDate.compareTo(aDate);
          });
          
          return decks.take(limit).toList();
        } catch (fallbackError) {
          debugPrint('❌ Fallback query also failed: $fallbackError');
          throw Exception('Failed to get reported decks: $fallbackError');
        }
      }
      debugPrint('❌ Error getting reported decks: $firebaseError');
      throw Exception('Failed to get reported decks: $firebaseError');
    } catch (e) {
      debugPrint('❌ Error getting reported decks: $e');
      throw Exception('Failed to get reported decks: $e');
    }
  }

  // Legacy methods for backward compatibility
  /// Approve deck (deprecated - use restoreDeck instead)
  @Deprecated('Use restoreDeck instead in post-moderation model')
  Future<void> approveDeck(String deckId) async {
    await restoreDeck(deckId);
  }

  /// Reject deck (deprecated - use hideDeck instead)
  @Deprecated('Use hideDeck instead in post-moderation model')
  Future<void> rejectDeck(String deckId, String reason) async {
    await hideDeck(deckId, reason);
  }

  /// Delete report
  Future<void> deleteReport(String reportId) async {
    try {
      await _reportsCollection.doc(reportId).delete();
      debugPrint('✅ Deleted report: $reportId');
    } catch (e) {
      debugPrint('❌ Error deleting report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Get admin statistics
  Future<Map<String, dynamic>> getAdminStatistics() async {
    try {
      // Count users
      final usersSnapshot = await _usersCollection.get();
      final totalUsers = usersSnapshot.docs.length;
      
      // Count active users (users who have created decks or studied)
      int activeUsers = 0;
      final now = DateTime.now();
      final monthAgo = now.subtract(const Duration(days: 30));
      
      for (var doc in usersSnapshot.docs) {
        final data = _safeGetDocumentData(doc);
        if (data != null) {
          final createdAt = data['createdAt'];
          if (createdAt != null) {
            try {
              DateTime userDate;
              if (createdAt is Timestamp) {
                userDate = createdAt.toDate();
              } else if (createdAt is String) {
                userDate = DateTime.parse(createdAt);
              } else {
                continue;
              }
              if (userDate.isAfter(monthAgo)) {
                activeUsers++;
              }
            } catch (e) {
              // Skip if can't parse
            }
          }
        }
      }
      
      // Count decks
      final decksSnapshot = await _decksCollection.get();
      final totalDecks = decksSnapshot.docs.length;
      
      // Count public decks
      int publicDecks = 0;
      int reportedDecks = 0;
      int hiddenDecks = 0;
      
      for (var doc in decksSnapshot.docs) {
        final data = _safeGetDocumentData(doc);
        if (data != null) {
          final isPublic = data['isPublic'] ?? false;
          final status = data['status'] as String? ?? '';
          
          if (isPublic && status != 'hidden') {
            publicDecks++;
          }
          if (status == 'reported') {
            reportedDecks++;
          }
          if (status == 'hidden') {
            hiddenDecks++;
          }
        }
      }
      
      // Count flashcards
      final flashcardsSnapshot = await _flashcardsCollection.get();
      final totalFlashcards = flashcardsSnapshot.docs.length;
      
      // Count pending reports
      final reportsSnapshot = await _reportsCollection
          .where('status', isEqualTo: 'pending')
          .get();
      final pendingReports = reportsSnapshot.docs.length;
      
      // Count total reports
      final allReportsSnapshot = await _reportsCollection.get();
      final totalReports = allReportsSnapshot.docs.length;
      
      // Count resolved reports
      final resolvedReportsSnapshot = await _reportsCollection
          .where('status', isEqualTo: 'resolved')
          .get();
      final resolvedReports = resolvedReportsSnapshot.docs.length;
      
      return {
        'totalUsers': totalUsers,
        'activeUsers': activeUsers,
        'totalDecks': totalDecks,
        'publicDecks': publicDecks,
        'reportedDecks': reportedDecks,
        'hiddenDecks': hiddenDecks,
        'totalFlashcards': totalFlashcards,
        'pendingReports': pendingReports,
        'totalReports': totalReports,
        'resolvedReports': resolvedReports,
      };
    } catch (e) {
      debugPrint('❌ Error getting admin statistics: $e');
      throw Exception('Failed to get admin statistics: $e');
    }
  }

  /// Get recent activities
  Future<List<Map<String, dynamic>>> getRecentActivities({int limit = 20}) async {
    try {
      final activities = <Map<String, dynamic>>[];
      
      // Get recent users (last 7 days)
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final recentUsers = await _usersCollection
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      for (var doc in recentUsers.docs) {
        final data = _safeGetDocumentData(doc);
        if (data != null) {
          activities.add({
            'type': 'user_registered',
            'title': 'Người dùng mới',
            'description': '${data['name'] ?? 'Unknown'} đã đăng ký',
            'timestamp': data['createdAt'],
            'userId': doc.id,
          });
        }
      }
      
      // Get recent decks (last 7 days)
      final recentDecks = await _decksCollection
          .where('createdAt', isGreaterThan: Timestamp.fromDate(weekAgo))
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      for (var doc in recentDecks.docs) {
        final data = _safeGetDocumentData(doc);
        if (data != null) {
          activities.add({
            'type': 'deck_created',
            'title': 'Deck mới',
            'description': 'Deck "${data['name'] ?? 'Unknown'}" đã được tạo',
            'timestamp': data['createdAt'],
            'deckId': doc.id,
          });
        }
      }
      
      // Get recent reports
      final recentReports = await _reportsCollection
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      for (var doc in recentReports.docs) {
        final data = _safeGetDocumentData(doc);
        if (data != null) {
          activities.add({
            'type': 'report_created',
            'title': 'Báo cáo mới',
            'description': 'Báo cáo về ${data['reportType'] ?? 'deck'} từ ${data['reporterName'] ?? 'Unknown'}',
            'timestamp': data['createdAt'],
            'reportId': doc.id,
          });
        }
      }
      
      // Sort by timestamp descending
      activities.sort((a, b) {
        final aTime = a['timestamp'];
        final bTime = b['timestamp'];
        
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        try {
          DateTime aDate, bDate;
          
          if (aTime is Timestamp) {
            aDate = aTime.toDate();
          } else if (aTime is String) {
            aDate = DateTime.parse(aTime);
          } else {
            return 0;
          }
          
          if (bTime is Timestamp) {
            bDate = bTime.toDate();
          } else if (bTime is String) {
            bDate = DateTime.parse(bTime);
          } else {
            return 0;
          }
          
          return bDate.compareTo(aDate);
        } catch (e) {
          return 0;
        }
      });
      
      return activities.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Error getting recent activities: $e');
      throw Exception('Failed to get recent activities: $e');
    }
  }
}
