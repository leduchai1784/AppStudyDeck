import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/firestore_repository.dart';

/// Service to manage authentication state using Firebase Auth
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirestoreRepository _firestoreRepo = FirestoreRepository();
  
  static Map<String, dynamic>? _currentUser;
  static User? get firebaseUser => _auth.currentUser;
  
  /// Check if user is logged in
  static bool get isLoggedIn => firebaseUser != null;
  
  /// Check if current user is admin
  static bool get isAdmin => _currentUser?['role'] == 'admin';
  
  /// Get current user data
  static Map<String, dynamic>? get currentUser => _currentUser;
  
  /// Get current user ID
  static String? get currentUserId => firebaseUser?.uid;

  /// Initialize auth state - call this on app start
  static Future<void> initialize() async {
    try {
      // Load current user if already logged in
      if (firebaseUser != null) {
        try {
          await _loadUserData(firebaseUser!.uid);
        } catch (e) {
          debugPrint('Warning: Failed to load user data on init: $e');
          // Continue anyway
        }
      }
      
      // Listen to auth state changes (don't use async in listener)
      _auth.authStateChanges().listen((User? user) {
        if (user != null) {
          _loadUserData(user.uid).catchError((e, stackTrace) {
            debugPrint('Error loading user data in listener: $e');
            debugPrint('Stack trace: $stackTrace');
          });
        } else {
          _currentUser = null;
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error initializing AuthService: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't throw - allow app to continue
    }
  }

  /// Load user data from Firestore
  static Future<void> _loadUserData(String userId) async {
    try {
      if (userId.isEmpty) {
        debugPrint('Cannot load user data: userId is empty');
        return;
      }
      
      // Validate userId format (should be a valid Firebase UID)
      if (userId.length < 20) {
        debugPrint('Warning: userId seems invalid: $userId');
      }
      
      // Get user data from Firestore
      debugPrint('🔍 Loading user data for userId: $userId');
      final userData = await _firestoreRepo.getUserById(userId);
      
      if (userData != null) {
        debugPrint('✅ User data retrieved from Firestore');
        debugPrint('📄 Data keys: ${userData.keys.toList()}');
        
        // Validate userData structure
        if (userData.containsKey('email') && userData.containsKey('name')) {
          _currentUser = userData;
          debugPrint('✅ User data loaded successfully for: ${userData['email']}');
        } else {
          debugPrint('⚠️ Warning: User data missing required fields: ${userData.keys}');
          // Still set it, but log warning
          _currentUser = userData;
          debugPrint('✅ User data loaded (with warnings)');
        }
      } else {
        // If user document doesn't exist, create it from Firebase Auth data
        debugPrint('⚠️ User document not found, creating new document...');
        final firebaseUser = _auth.currentUser;
        if (firebaseUser != null && firebaseUser.uid == userId) {
          try {
            await _createUserDocument(firebaseUser);
            // Try to load again after creating
            debugPrint('🔍 Retrying to load user data after creating document...');
            final newUserData = await _firestoreRepo.getUserById(userId);
            if (newUserData != null) {
              _currentUser = newUserData;
              debugPrint('✅ User document created and loaded successfully');
            } else {
              debugPrint('⚠️ Warning: Failed to load user data after creating document');
            }
          } catch (createError, createStack) {
            debugPrint('❌ Error creating user document: $createError');
            debugPrint('❌ Error type: ${createError.runtimeType}');
            debugPrint('❌ Stack trace: $createStack');
            // Don't throw - user is authenticated, just document creation failed
          }
        } else {
          debugPrint('⚠️ Warning: Firebase user not found or userId mismatch');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading user data: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Stack trace: $stackTrace');
      // Don't set _currentUser to null on error, keep existing data
      // This prevents app crash if Firestore is temporarily unavailable
      // Re-throw only if it's a critical error that should be handled upstream
      // For type casting errors, we'll just log and continue
      if (e.toString().contains('is not a subtype') || 
          e.toString().contains('type cast') ||
          e.toString().contains('List<Object?>')) {
        debugPrint('⚠️ Type casting error detected - continuing without loading user data');
        // Don't rethrow - this is a data format issue, not a critical error
      } else {
        // For other errors, also don't rethrow to prevent app crash
        debugPrint('⚠️ Non-critical error - continuing without loading user data');
      }
    }
  }

  /// Create user document in Firestore
  /// [provider] - Authentication provider: 'email', 'google', 'facebook'
  /// [googleUser] - Optional GoogleSignInAccount for Google Sign-In
  static Future<void> _createUserDocument(
    User firebaseUser, {
    String provider = 'email',
    dynamic googleUser,
  }) async {
    try {
      // Determine provider from Firebase User
      String actualProvider = provider;
      if (firebaseUser.providerData.isNotEmpty) {
        final providerData = firebaseUser.providerData.first;
        if (providerData.providerId == 'google.com') {
          actualProvider = 'google';
        } else if (providerData.providerId == 'facebook.com') {
          actualProvider = 'facebook';
        } else if (providerData.providerId == 'password') {
          actualProvider = 'email';
        }
      }

      final userData = <String, dynamic>{
        'email': firebaseUser.email ?? '',
        'name': firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
        'role': 'user', // Default role
        'isBlocked': false,
        'provider': actualProvider,
        'emailVerified': firebaseUser.emailVerified,
        'statistics': <String, dynamic>{
          'totalDecksCreated': 0,
          'totalFlashcardsCreated': 0,
          'totalDecksStudied': 0,
          'totalFlashcardsStudied': 0,
          'totalStudyTime': 0,
        },
        // createdAt and updatedAt will be set by FirestoreRepository using serverTimestamp
      };

      // Add Google-specific fields if provider is Google
      if (actualProvider == 'google' && googleUser != null) {
        // googleUser is GoogleSignInAccount
        userData['providerId'] = googleUser.id;
        userData['photoUrl'] = googleUser.photoUrl;
        
        // Also use photoUrl from Firebase User if available
        if (firebaseUser.photoURL != null) {
          userData['photoUrl'] = firebaseUser.photoURL;
        }
        
        // Add locale if available from Google account
        // Note: GoogleSignInAccount doesn't have locale, but we can get it from Firebase User metadata
      } else if (actualProvider == 'google') {
        // Fallback: use Firebase User data if googleUser is not provided
        userData['photoUrl'] = firebaseUser.photoURL;
        
        // Get provider ID from Firebase User providerData
        if (firebaseUser.providerData.isNotEmpty) {
          final googleProviderData = firebaseUser.providerData
              .firstWhere((p) => p.providerId == 'google.com', orElse: () => firebaseUser.providerData.first);
          userData['providerId'] = googleProviderData.uid;
        }
      }

      // Add phone number if available
      if (firebaseUser.phoneNumber != null && firebaseUser.phoneNumber!.isNotEmpty) {
        userData['phoneNumber'] = firebaseUser.phoneNumber;
      }

      // Use avatarUrl field for backward compatibility
      if (userData.containsKey('photoUrl') && userData['photoUrl'] != null) {
        userData['avatarUrl'] = userData['photoUrl'];
      }
      
      await _firestoreRepo.createOrUpdateUser(
        userId: firebaseUser.uid,
        userData: userData,
      );
    } catch (e) {
      debugPrint('Error creating user document: $e');
      rethrow;
    }
  }

  /// Login with email and password
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔄 Starting login process...');
      debugPrint('📧 Email: ${email.trim()}');
      
      // Step 1: Sign in with Firebase Auth
      debugPrint('🔐 Step 1: Signing in with Firebase Auth...');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (userCredential.user == null) {
        debugPrint('❌ ERROR: User credential is null');
        return false;
      }
      
      final userId = userCredential.user!.uid;
      debugPrint('✅ Step 1 completed: User signed in with ID: $userId');
      
      // Step 2: Wait for Firebase Auth to fully initialize
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 3: Load user data from Firestore
      debugPrint('📥 Step 2: Loading user data from Firestore...');
      try {
        await _loadUserData(userId);
        debugPrint('✅ Step 2 completed: User data loaded successfully');
        
        // Step 3.5: Check if user is blocked
        debugPrint('🔒 Step 2.5: Checking if user is blocked...');
        if (_currentUser != null && _currentUser!['isBlocked'] == true) {
          debugPrint('❌ User is blocked, logging out...');
          await logout();
          throw Exception('Tài khoản của bạn đã bị khóa.\nVui lòng liên hệ quản trị viên để được hỗ trợ.');
        }
        debugPrint('✅ Step 2.5 completed: User is not blocked');
      } catch (e, stackTrace) {
        debugPrint('⚠️ WARNING: Failed to load user data: $e');
        debugPrint('Stack trace: $stackTrace');
        
        // If error is about blocked user, rethrow it
        if (e.toString().contains('bị khóa') || e.toString().contains('blocked')) {
          rethrow;
        }
        
        // If user document doesn't exist, create it from Firebase Auth data
        debugPrint('📝 Attempting to create user document from Firebase Auth data...');
        try {
          final firebaseUser = _auth.currentUser;
          if (firebaseUser != null) {
            await _createUserDocument(firebaseUser);
            await _loadUserData(userId);
            debugPrint('✅ User document created and loaded successfully');
            
            // Check blocked status after creating document
            if (_currentUser != null && _currentUser!['isBlocked'] == true) {
              debugPrint('❌ User is blocked, logging out...');
              await logout();
              throw Exception('Tài khoản của bạn đã bị khóa.\nVui lòng liên hệ quản trị viên để được hỗ trợ.');
            }
          }
        } catch (createError) {
          debugPrint('❌ ERROR: Failed to create user document: $createError');
          // Continue anyway - user is authenticated
        }
      }
      
      // Step 4: Update lastLoginAt
      debugPrint('📅 Step 3: Updating lastLoginAt...');
      try {
        await _firestoreRepo.updateUser(userId, {
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Step 3 completed: lastLoginAt updated');
      } catch (e) {
        debugPrint('⚠️ WARNING: Failed to update lastLoginAt: $e');
        // Don't fail login if this fails
      }
      
      debugPrint('🎉 Login completed successfully!');
      return true;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during login: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Register new user with email and password
  static Future<bool> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      debugPrint('🔄 Starting registration process...');
      debugPrint('📧 Email: ${email.trim()}');
      debugPrint('👤 Name: $name');
      
      // Step 1: Create user in Firebase Auth
      debugPrint('📝 Step 1: Creating user in Firebase Auth...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      if (userCredential.user == null) {
        debugPrint('❌ ERROR: User credential is null');
        return false;
      }
      
      final userId = userCredential.user!.uid;
      debugPrint('✅ Step 1 completed: User created in Firebase Auth with ID: $userId');
      
      // Step 2: Wait for Firebase Auth to fully initialize
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Step 3: Verify user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null || currentUser.uid != userId) {
        debugPrint('❌ ERROR: User not authenticated after registration');
        throw Exception('User authentication failed after registration');
      }
      debugPrint('✅ Step 2 completed: User is authenticated');
      
      // Step 3.5: Update Firebase Auth profile with displayName (họ tên)
      debugPrint('📝 Step 2.5: Updating Firebase Auth profile with displayName...');
      try {
        await currentUser.updateDisplayName(name.trim());
        await currentUser.reload();
        debugPrint('✅ Firebase Auth profile updated with displayName: ${name.trim()}');
      } catch (updateError) {
        debugPrint('⚠️ WARNING: Failed to update Firebase Auth displayName: $updateError');
        // Continue anyway - name will still be saved to Firestore
      }
      
      // Step 4: Prepare user data for Firestore
      // IMPORTANT: Use name from registration form, not from Firebase Auth
      debugPrint('📝 Step 3: Preparing user data for Firestore...');
      final trimmedName = name.trim();
      final userData = <String, dynamic>{
        'email': email.trim(),
        'name': trimmedName, // Lưu họ tên từ form đăng ký
        'role': 'user',
        'isBlocked': false,
        'provider': 'email', // Đánh dấu đăng ký bằng email
        'emailVerified': false, // Email chưa được verify khi đăng ký
        'statistics': <String, dynamic>{
          'totalDecksCreated': 0,
          'totalFlashcardsCreated': 0,
          'totalDecksStudied': 0,
          'totalFlashcardsStudied': 0,
          'totalStudyTime': 0,
        },
      };
      debugPrint('📦 User data prepared: $userData');
      debugPrint('📦 Name (họ tên) to save: $trimmedName');
      
      // Step 5: Create user document in Firestore
      debugPrint('💾 Step 4: Creating user document in Firestore...');
      await _firestoreRepo.createOrUpdateUser(
        userId: userId,
        userData: userData,
      );
      debugPrint('✅ Step 4 completed: User document created in Firestore');
      
      // Step 6: Verify document was created
      debugPrint('🔍 Step 5: Verifying document creation...');
      await Future.delayed(const Duration(milliseconds: 500));
      final verifyDoc = await _firestoreRepo.getUserById(userId);
      if (verifyDoc == null) {
        debugPrint('❌ ERROR: Document verification failed - document not found');
        throw Exception('Không thể xác minh tài khoản đã được tạo. Vui lòng thử lại.');
      }
      debugPrint('✅ Step 5 completed: Document verified successfully');
      debugPrint('📄 Document data: $verifyDoc');
      
      // Step 7: Load user data into memory
      // Use the verified document data directly instead of calling getUserById again
      // This avoids potential type casting errors when reading from Firestore
      // IMPORTANT: At this point, document is already created and verified in Firestore
      // So even if loading into memory fails, registration is still successful
      debugPrint('📥 Step 6: Loading user data into memory...');
      bool memoryLoadSuccess = false;
      
      try {
        // Validate userData structure
        if (verifyDoc.containsKey('email') && verifyDoc.containsKey('name')) {
          _currentUser = verifyDoc;
          memoryLoadSuccess = true;
          debugPrint('✅ Step 6 completed: User data loaded into memory');
          debugPrint('✅ User email: ${verifyDoc['email']}');
        } else {
          debugPrint('⚠️ WARNING: User data missing required fields: ${verifyDoc.keys}');
          // Still set it, but log warning
          _currentUser = verifyDoc;
          memoryLoadSuccess = true;
          debugPrint('✅ Step 6 completed: User data loaded (with warnings)');
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ WARNING: Error setting user data in memory: $e');
        debugPrint('⚠️ Error type: ${e.runtimeType}');
        debugPrint('⚠️ Stack trace: $stackTrace');
        
        // Try to load again using _loadUserData as fallback
        try {
          debugPrint('🔄 Attempting fallback: Loading user data via _loadUserData...');
          await _loadUserData(userId);
          memoryLoadSuccess = true;
          debugPrint('✅ Step 6 completed: User data loaded via fallback method');
        } catch (loadError, loadStack) {
          debugPrint('⚠️ WARNING: Fallback load also failed: $loadError');
          debugPrint('⚠️ Fallback error type: ${loadError.runtimeType}');
          debugPrint('⚠️ Fallback stack trace: $loadStack');
          
          // Check if it's a type casting error - if so, try to set basic data
          if (loadError.toString().contains('is not a subtype') || 
              loadError.toString().contains('type cast') ||
              loadError.toString().contains('List<Object?>')) {
            debugPrint('⚠️ Type casting error detected - setting basic user data');
            try {
              // Set minimal user data from Firebase Auth
              final firebaseUser = _auth.currentUser;
              if (firebaseUser != null) {
                _currentUser = {
                  'userId': firebaseUser.uid,
                  'email': firebaseUser.email ?? email.trim(),
                  'name': name.trim(),
                  'role': 'user',
                };
                memoryLoadSuccess = true;
                debugPrint('✅ Step 6 completed: Basic user data set from Firebase Auth');
              }
            } catch (basicError) {
              debugPrint('⚠️ WARNING: Even basic data setting failed: $basicError');
              // Still continue - document exists in Firestore, data will load on next app start
            }
          }
          
          if (!memoryLoadSuccess) {
            debugPrint('⚠️ WARNING: Could not load user data into memory');
            debugPrint('⚠️ However, document exists in Firestore and will be loaded on next app start');
          }
        }
      }
      
      // At this point, document is successfully created and verified in Firestore
      // Registration is successful regardless of memory loading status
      if (memoryLoadSuccess) {
        debugPrint('🎉 Registration completed successfully with user data in memory!');
      } else {
        debugPrint('🎉 Registration completed successfully! (User data will load on next app start)');
      }
      return true;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during registration: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Login with Google
  static Future<bool> loginWithGoogle() async {
    try {
      debugPrint('🔄 Starting Google Sign-In process...');
      
      // Step 1: Initialize Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      
      // Step 2: Trigger the authentication flow
      debugPrint('🔐 Step 1: Triggering Google Sign-In...');
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('❌ User cancelled Google Sign-In');
        return false;
      }
      
      debugPrint('✅ Step 1 completed: Google account selected');
      debugPrint('📧 Email: ${googleUser.email}');
      debugPrint('👤 Name: ${googleUser.displayName}');
      
      // Step 3: Obtain the auth details from the request
      debugPrint('🔑 Step 2: Obtaining authentication credentials...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Step 4: Create a new credential
      debugPrint('🔐 Step 3: Creating Firebase credential...');
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // Step 5: Sign in to Firebase with the Google credential
      debugPrint('🔥 Step 4: Signing in to Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        debugPrint('❌ ERROR: User credential is null');
        return false;
      }
      
      final userId = userCredential.user!.uid;
      debugPrint('✅ Step 4 completed: User signed in to Firebase with ID: $userId');
      
      // Step 6: Wait for Firebase Auth to fully initialize
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Step 7: Load user data from Firestore
      debugPrint('📥 Step 5: Loading user data from Firestore...');
      try {
        await _loadUserData(userId);
        debugPrint('✅ Step 5 completed: User data loaded successfully');
        
        // Step 7.5: Check if user is blocked
        debugPrint('🔒 Step 5.5: Checking if user is blocked...');
        if (_currentUser != null && _currentUser!['isBlocked'] == true) {
          debugPrint('❌ User is blocked, logging out...');
          await logout();
          throw Exception('Tài khoản của bạn đã bị khóa.\nVui lòng liên hệ quản trị viên để được hỗ trợ.');
        }
        debugPrint('✅ Step 5.5 completed: User is not blocked');
      } catch (e, stackTrace) {
        debugPrint('⚠️ WARNING: Failed to load user data: $e');
        debugPrint('Stack trace: $stackTrace');
        
        // If error is about blocked user, rethrow it
        if (e.toString().contains('bị khóa') || e.toString().contains('blocked')) {
          rethrow;
        }
        
        // If user document doesn't exist, create it from Firebase Auth data
        debugPrint('📝 Attempting to create user document from Firebase Auth data...');
        try {
          final firebaseUser = _auth.currentUser;
          if (firebaseUser != null) {
            // Update display name if available from Google account
            if (firebaseUser.displayName == null && googleUser.displayName != null) {
              try {
                await firebaseUser.updateDisplayName(googleUser.displayName);
                await firebaseUser.reload();
              } catch (updateError) {
                debugPrint('⚠️ WARNING: Failed to update display name: $updateError');
              }
            }
            
            // Create user document with Google provider information
            await _createUserDocument(
              firebaseUser,
              provider: 'google',
              googleUser: googleUser,
            );
            await _loadUserData(userId);
            debugPrint('✅ User document created and loaded successfully');
            
            // Check blocked status after creating document
            if (_currentUser != null && _currentUser!['isBlocked'] == true) {
              debugPrint('❌ User is blocked, logging out...');
              await logout();
              throw Exception('Tài khoản của bạn đã bị khóa.\nVui lòng liên hệ quản trị viên để được hỗ trợ.');
            }
          }
        } catch (createError) {
          debugPrint('❌ ERROR: Failed to create user document: $createError');
          // Continue anyway - user is authenticated
        }
      }
      
      // Step 8: Update lastLoginAt
      debugPrint('📅 Step 6: Updating lastLoginAt...');
      try {
        await _firestoreRepo.updateUser(userId, {
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Step 6 completed: lastLoginAt updated');
      } catch (e) {
        debugPrint('⚠️ WARNING: Failed to update lastLoginAt: $e');
        // Don't fail login if this fails
      }
      
      debugPrint('🎉 Google Sign-In completed successfully!');
      return true;
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error during Google Sign-In: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Login with Facebook
  static Future<bool> loginWithFacebook() async {
    // TODO: Implement Facebook Sign In
    // For now, return false
    return false;
  }

  /// Send password reset email
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      debugPrint('📧 Sending password reset email to: ${email.trim()}');
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('✅ Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error sending password reset email: $e');
      rethrow;
    }
  }

  /// Send email verification
  static Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      if (user.email == null) {
        throw Exception('Người dùng không có email');
      }

      if (user.emailVerified) {
        throw Exception('Email đã được xác thực');
      }

      debugPrint('📧 Sending email verification to: ${user.email}');
      await user.sendEmailVerification();
      debugPrint('✅ Email verification sent successfully');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error sending email verification: $e');
      rethrow;
    }
  }

  /// Update email with reauthentication
  static Future<void> updateEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      if (user.email == null) {
        throw Exception('Không thể đổi email cho tài khoản này');
      }

      debugPrint('🔄 Starting email update process...');
      
      // Step 1: Reauthenticate user
      debugPrint('🔐 Step 1: Reauthenticating user...');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      debugPrint('✅ Step 1 completed: User reauthenticated');

      // Step 2: Update email
      // Note: updateEmail is deprecated but still works. 
      // Consider using verifyBeforeUpdateEmail() for better security
      debugPrint('📧 Step 2: Updating email...');
      // ignore: deprecated_member_use
      await user.updateEmail(newEmail.trim());
      await user.reload();
      debugPrint('✅ Step 2 completed: Email updated successfully');
      
      debugPrint('🎉 Email update completed successfully!');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error updating email: $e');
      rethrow;
    }
  }

  /// Get error message for email verification
  static String getEmailVerificationErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu.\nVui lòng đợi một lát rồi thử lại';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại';
      default:
        return 'Đã xảy ra lỗi: ${e.message ?? e.code}';
    }
  }

  /// Get error message for email update
  static String getEmailUpdateErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Mật khẩu không đúng.\nVui lòng kiểm tra lại';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.\nVui lòng sử dụng email khác';
      case 'invalid-email':
        return 'Email không hợp lệ.\nVui lòng nhập đúng định dạng email';
      case 'requires-recent-login':
        return 'Vui lòng đăng xuất và đăng nhập lại trước khi đổi email';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu.\nVui lòng đợi một lát rồi thử lại';
      default:
        return 'Đã xảy ra lỗi: ${e.message ?? e.code}';
    }
  }

  /// Change password for logged in user
  /// Requires reauthentication with current password
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Người dùng chưa đăng nhập');
      }

      if (user.email == null) {
        throw Exception('Không thể đổi mật khẩu cho tài khoản này');
      }

      debugPrint('🔄 Starting password change process...');
      
      // Step 1: Reauthenticate user with current password
      debugPrint('🔐 Step 1: Reauthenticating user...');
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      debugPrint('✅ Step 1 completed: User reauthenticated');

      // Step 2: Update password
      debugPrint('🔑 Step 2: Updating password...');
      await user.updatePassword(newPassword);
      debugPrint('✅ Step 2 completed: Password updated successfully');
      
      debugPrint('🎉 Password change completed successfully!');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('❌ Error changing password: $e');
      rethrow;
    }
  }

  /// Get error message for password change
  static String getPasswordChangeErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        return 'Mật khẩu hiện tại không đúng.\nVui lòng kiểm tra lại';
      case 'weak-password':
        return 'Mật khẩu mới quá yếu.\nVui lòng sử dụng mật khẩu có ít nhất 6 ký tự';
      case 'requires-recent-login':
        return 'Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu.\nVui lòng đợi một lát rồi thử lại';
      default:
        return 'Đã xảy ra lỗi: ${e.message ?? e.code}';
    }
  }

  /// Logout
  static Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    }
  }

  /// Get error message from Firebase Auth exception
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.\nVui lòng kiểm tra lại email hoặc đăng ký tài khoản mới';
      case 'wrong-password':
        return 'Mật khẩu không đúng.\nVui lòng kiểm tra lại mật khẩu';
      case 'email-already-in-use':
        return 'Email này đã được sử dụng.\nVui lòng đăng nhập hoặc sử dụng email khác';
      case 'invalid-email':
        return 'Email không hợp lệ.\nVui lòng nhập đúng định dạng email';
      case 'weak-password':
        return 'Mật khẩu quá yếu.\nVui lòng sử dụng mật khẩu có ít nhất 6 ký tự';
      case 'user-disabled':
        return 'Tài khoản này đã bị vô hiệu hóa.\nVui lòng liên hệ quản trị viên';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu.\nVui lòng đợi một lát rồi thử lại';
      case 'operation-not-allowed':
        return 'Thao tác không được phép.\nVui lòng liên hệ quản trị viên';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng.\nVui lòng kiểm tra:\n- Kết nối internet\n- Firewall/Proxy không chặn Firebase\n- Android Emulator có internet (Settings > Network)';
      default:
        return 'Đã xảy ra lỗi: ${e.message ?? e.code}';
    }
  }

  /// Get error message for password reset
  static String getPasswordResetErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Không tìm thấy tài khoản với email này.\nVui lòng kiểm tra lại email';
      case 'invalid-email':
        return 'Email không hợp lệ.\nVui lòng nhập đúng định dạng email';
      case 'too-many-requests':
        return 'Quá nhiều yêu cầu.\nVui lòng đợi một lát rồi thử lại';
      case 'network-request-failed':
        return 'Lỗi kết nối mạng.\nVui lòng kiểm tra internet và thử lại';
      default:
        return 'Đã xảy ra lỗi: ${e.message ?? e.code}';
    }
  }
}

