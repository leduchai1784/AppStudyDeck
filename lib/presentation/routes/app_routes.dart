import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../auth/forgot_password_screen.dart';
import '../user/home/home_screen.dart';
import '../user/deck/deck_list_screen.dart';
import '../user/deck/deck_detail_screen.dart';
import '../user/flashcard/flashcard_edit_screen.dart';
import '../user/flashcard/flashcard_bulk_add_screen.dart';
import '../user/study/study_screen.dart';
import '../user/settings/settings_screen.dart';
import '../user/settings/change_password_screen.dart';
import '../user/settings/edit_profile_screen.dart';
import '../user/search/search_screen.dart';
import '../user/notifications/notifications_screen.dart';
import '../user/statistics/statistics_screen.dart';
import '../admin/admin_home.dart';
import '../admin/dashboard/dashboard_screen.dart';
import '../admin/manage_users/manage_users_screen.dart';
import '../admin/manage_users/user_detail_screen.dart';
import '../admin/manage_decks/manage_decks_screen.dart';
import '../admin/manage_decks/deck_review_screen.dart';
import '../admin/manage_reports/manage_reports_screen.dart';
import '../admin/manage_reports/report_detail_screen.dart';

class AppRoutes {
  // Route names
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String settings = '/settings';
  static const String changePassword = '/change-password';
  static const String editProfile = '/edit-profile';
  static const String home = '/home';
  static const String deckList = '/deck-list';
  static const String deckDetail = '/deck-detail';
  static const String flashcardEdit = '/flashcard-edit';
  static const String flashcardBulkAdd = '/flashcard-bulk-add';
  static const String study = '/study';
  static const String search = '/search';
  static const String notifications = '/notifications';
  static const String statistics = '/statistics';
  static const String adminHome = '/admin';
  static const String adminDashboard = '/admin/dashboard';
  static const String manageUsers = '/admin/users';
  static const String userDetail = '/admin/users/detail';
  static const String manageDecks = '/admin/decks';
  static const String deckReview = '/admin/decks/review';
  static const String manageReports = '/admin/reports';
  static const String reportDetail = '/admin/reports/detail';

  // Route generator
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final args = routeSettings.arguments;
    final routeName = routeSettings.name;

    switch (routeName) {
      // Auth routes
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case settings:
        final fromAdmin = args is bool ? args : false;
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(fromAdmin: fromAdmin),
        );
      case changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());
      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileScreen());

      // User routes
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case deckList:
        return MaterialPageRoute(builder: (_) => const DeckListScreen());
      case deckDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => DeckDetailScreen(deckId: args),
          );
        }
        return _errorRoute('Deck ID is required');
      case flashcardEdit:
        if (args is Map<String, String?>) {
          return MaterialPageRoute(
            builder: (_) => FlashcardEditScreen(
              deckId: args['deckId'],
              flashcardId: args['flashcardId'],
            ),
          );
        }
        return _errorRoute('Invalid arguments');
      case flashcardBulkAdd:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => FlashcardBulkAddScreen(deckId: args),
          );
        }
        return _errorRoute('Deck ID is required');
      case study:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => StudyScreen(deckId: args),
          );
        }
        return _errorRoute('Deck ID is required');
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsScreen());

      // Admin routes
      case adminHome:
        return MaterialPageRoute(builder: (_) => const AdminHomeScreen());
      case adminDashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case manageUsers:
        return MaterialPageRoute(builder: (_) => const ManageUsersScreen());
      case userDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => UserDetailScreen(userId: args),
          );
        }
        return _errorRoute('User ID is required');
      case manageDecks:
        return MaterialPageRoute(builder: (_) => const ManageDecksScreen());
      case deckReview:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => DeckReviewScreen(deckId: args),
          );
        }
        return _errorRoute('Deck ID is required');
      case manageReports:
        return MaterialPageRoute(builder: (_) => const ManageReportsScreen());
      case reportDetail:
        if (args is String) {
          return MaterialPageRoute(
            builder: (_) => ReportDetailScreen(reportId: args),
          );
        }
        return _errorRoute('Report ID is required');

      default:
        return _errorRoute('Route not found');
    }
  }

  static Route<dynamic> _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text(message),
        ),
      ),
    );
  }
}

