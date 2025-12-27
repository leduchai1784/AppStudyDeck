# Hướng dẫn Setup Firebase cho Flashcard Study Deck

## Tổng quan

Dự án đã được cấu hình để kết nối với Firebase. Tài liệu này hướng dẫn cách setup và sử dụng Firebase trong ứng dụng.

---

## 1. Firebase Configuration

### 1.1. Thông tin Project Firebase

- **Project ID**: `appstudydeck-e036d`
- **Project Number**: `542729551050`
- **Storage Bucket**: `appstudydeck-e036d.firebasestorage.app`

### 1.2. API Keys

- **Web API Key**: `AIzaSyAJQoX3T5k69HvUYekS-CTnbjzyRQvqkXA`
- **Android API Key**: `AIzaSyCkNgYJwze5_t_AwXTLNuNALDBDEaWqo3Y`
- **iOS API Key**: `AIzaSyB0_onwkvdDEXtRTP33FLI2vETrBtZLO0A`

---

## 2. Files đã được cấu hình

### 2.1. Android
- ✅ `android/app/google-services.json` - Đã có
- ✅ `android/build.gradle.kts` - Đã thêm Google Services plugin
- ✅ `android/app/build.gradle.kts` - Đã apply Google Services plugin

### 2.2. iOS
- ✅ `ios/Runner/GoogleService-Info.plist` - Đã có

### 2.3. Flutter Code
- ✅ `lib/core/firebase/firebase_options.dart` - Firebase options cho các platform
- ✅ `lib/core/firebase/firebase_service.dart` - Service để initialize Firebase
- ✅ `lib/main.dart` - Đã initialize Firebase trong main()

### 2.4. Dependencies
- ✅ `pubspec.yaml` - Đã thêm Firebase packages

---

## 3. Firebase Packages đã thêm

```yaml
dependencies:
  firebase_core: ^2.24.2          # Core Firebase SDK
  firebase_auth: ^4.15.3           # Authentication
  cloud_firestore: ^4.13.6         # Firestore Database
  firebase_analytics: ^10.7.4      # Analytics
  firebase_storage: ^11.6.0         # Storage
```

---

## 4. Cấu trúc Firebase Code

### 4.1. Firebase Options (`lib/core/firebase/firebase_options.dart`)

File này chứa cấu hình Firebase cho các platform:
- **Web**: Sử dụng config từ Firebase Console
- **Android**: Sử dụng config từ `google-services.json`
- **iOS**: Sử dụng config từ `GoogleService-Info.plist`

### 4.2. Firebase Service (`lib/core/firebase/firebase_service.dart`)

Service để initialize Firebase:
```dart
await FirebaseService.initialize();
```

### 4.3. Main.dart

Firebase được initialize trong `main()`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();
  runApp(const MyApp());
}
```

---

## 5. Các bước tiếp theo để sử dụng Firebase

### 5.1. Chạy lệnh để cài đặt dependencies

```bash
flutter pub get
```

### 5.2. Tạo Firestore Repository

Tạo file `lib/data/repositories/firestore_repository.dart` để thay thế MockApi:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/deck_model.dart';
import '../models/flashcard_model.dart';

class FirestoreRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Users collection
  CollectionReference get _users => _firestore.collection('users');
  
  // Decks collection
  CollectionReference get _decks => _firestore.collection('decks');
  
  // Flashcards collection
  CollectionReference get _flashcards => _firestore.collection('flashcards');
  
  // Reports collection
  CollectionReference get _reports => _firestore.collection('reports');
  
  // Implement các methods tương tự MockApi
  // ...
}
```

### 5.3. Tạo Firebase Auth Service

Cập nhật `lib/core/services/auth_service.dart` để sử dụng Firebase Auth:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  
  Future<bool> login({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Get user data from Firestore
      final userDoc = await _firestore.collection('users').doc(credential.user?.uid).get();
      // ...
      return true;
    } catch (e) {
      return false;
    }
  }
  
  // Implement các methods khác...
}
```

---

## 6. Firestore Database Setup

### 6.1. Tạo Collections trong Firebase Console

Theo thiết kế trong `FIREBASE_DATABASE_DESIGN.md`, cần tạo các collections:

1. **users** - Thông tin người dùng
2. **decks** - Thông tin các deck
3. **flashcards** - Các flashcard
4. **user_deck_progress** - Tiến độ học của user với deck
5. **user_flashcard_progress** - Tiến độ chi tiết với từng flashcard
6. **deck_favorites** - Deck được user yêu thích
7. **reports** - Báo cáo từ users
8. **study_sessions** - Lịch sử phiên học tập

### 6.2. Setup Security Rules

Copy Security Rules từ `FIREBASE_DATABASE_DESIGN.md` vào Firebase Console:
- Vào Firebase Console → Firestore Database → Rules
- Paste rules và publish

### 6.3. Tạo Indexes

Tạo các composite indexes trong Firebase Console:
- Vào Firestore Database → Indexes
- Tạo các indexes theo danh sách trong `FIREBASE_DATABASE_DESIGN.md`

---

## 7. Testing Firebase Connection

### 7.1. Test kết nối

Tạo file test để kiểm tra kết nối:

```dart
// Test trong main.dart hoặc tạo test file
void testFirebaseConnection() async {
  try {
    await FirebaseService.initialize();
    print('✅ Firebase initialized successfully');
    
    // Test Firestore connection
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('test').doc('test').set({'test': true});
    print('✅ Firestore connection successful');
    
    // Test Auth
    final auth = FirebaseAuth.instance;
    print('✅ Firebase Auth ready');
  } catch (e) {
    print('❌ Firebase connection error: $e');
  }
}
```

### 7.2. Chạy ứng dụng

```bash
flutter run
```

Kiểm tra console để xem Firebase có initialize thành công không.

---

## 8. Migration từ MockApi sang Firebase

### 8.1. Strategy

1. **Phase 1**: Giữ MockApi, tạo FirestoreRepository song song
2. **Phase 2**: Tạo abstraction layer (Repository interface)
3. **Phase 3**: Switch từ MockApi sang FirestoreRepository
4. **Phase 4**: Xóa MockApi khi đã test đầy đủ

### 8.2. Repository Pattern

Tạo interface để abstract:

```dart
// lib/domain/repositories/deck_repository.dart
abstract class DeckRepository {
  Future<List<DeckModel>> getDecks({String? userId});
  Future<DeckModel?> getDeckById(String deckId);
  Future<DeckModel> createDeck({...});
  // ...
}
```

Implement cả 2:
- `MockDeckRepository` - Sử dụng MockApi
- `FirestoreDeckRepository` - Sử dụng Firestore

---

## 9. Troubleshooting

### 9.1. Lỗi thường gặp

1. **Firebase not initialized**
   - Kiểm tra `main()` có gọi `FirebaseService.initialize()` chưa
   - Kiểm tra `WidgetsFlutterBinding.ensureInitialized()` được gọi trước

2. **Google Services plugin error**
   - Đảm bảo `google-services.json` đúng vị trí
   - Kiểm tra `build.gradle.kts` đã apply plugin chưa

3. **iOS build error**
   - Kiểm tra `GoogleService-Info.plist` đã được add vào Xcode project
   - Chạy `pod install` trong thư mục `ios/`

### 9.2. Commands hữu ích

```bash
# Clean và rebuild
flutter clean
flutter pub get
flutter run

# iOS specific
cd ios
pod install
cd ..

# Android specific
cd android
./gradlew clean
cd ..
```

---

## 10. Next Steps

1. ✅ Firebase đã được setup và initialize
2. ⏳ Tạo FirestoreRepository để thay thế MockApi
3. ⏳ Implement Firebase Auth
4. ⏳ Migrate data từ MockApi sang Firestore
5. ⏳ Test tất cả chức năng với Firebase
6. ⏳ Deploy Security Rules và Indexes

---

## 11. Resources

- [Firebase Flutter Documentation](https://firebase.flutter.dev/)
- [Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [FIREBASE_DATABASE_DESIGN.md](./FIREBASE_DATABASE_DESIGN.md) - Thiết kế database chi tiết

---

## Kết luận

Firebase đã được cấu hình và sẵn sàng sử dụng. Bước tiếp theo là tạo Repository layer để kết nối với Firestore và thay thế MockApi.
