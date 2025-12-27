/// Constants for the application
class AppConstants {
  // Mock credentials for testing (remove in production)
  static const String mockAdminEmail = 'admin@example.com';
  static const String mockAdminPassword = 'admin123';
  
  static const String mockUserEmail = 'user@example.com';
  static const String mockUserPassword = 'user123';
  
  // App info
  static const String appName = 'Flashcard Study Deck';
  static const String appVersion = '1.0.0';
  
  // Validation rules
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  
  // API endpoints (when implemented)
  static const String baseUrl = 'https://api.example.com';
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
}

