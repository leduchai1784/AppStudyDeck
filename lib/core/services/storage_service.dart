import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service to handle file uploads to Firebase Storage
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload avatar image to Firebase Storage
  /// Returns the download URL of the uploaded image
  static Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
  }) async {
    try {
      debugPrint('📤 Uploading avatar for user: $userId');
      
      // Create reference to avatar file
      final ref = _storage.ref().child('avatars/$userId.jpg');
      
      // Upload file
      final uploadTask = ref.putFile(imageFile);
      
      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      debugPrint('✅ Avatar uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading avatar: $e');
      rethrow;
    }
  }

  /// Delete avatar from Firebase Storage
  static Future<void> deleteAvatar(String userId) async {
    try {
      debugPrint('🗑️ Deleting avatar for user: $userId');
      
      final ref = _storage.ref().child('avatars/$userId.jpg');
      await ref.delete();
      
      debugPrint('✅ Avatar deleted successfully');
    } catch (e) {
      debugPrint('❌ Error deleting avatar: $e');
      // Don't throw - if file doesn't exist, that's okay
      if (e.toString().contains('No such object')) {
        debugPrint('⚠️ Avatar file does not exist, skipping deletion');
        return;
      }
      rethrow;
    }
  }
}

