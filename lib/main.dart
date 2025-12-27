import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/firebase/firebase_service.dart';
import 'core/services/auth_service.dart';
import 'core/providers/theme_provider.dart';
import 'presentation/routes/app_routes.dart';
import 'presentation/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  try {
    await FirebaseService.initialize();
    
    // Initialize Auth Service (listens to auth state changes)
    await AuthService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
    // App can still run with MockApi if Firebase fails
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Flashcard Study Deck',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              cardTheme: CardThemeData(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            themeMode: themeProvider.themeMode,
            // Auto-redirect based on auth state
            home: const AuthWrapper(),
            onGenerateRoute: AppRoutes.generateRoute,
          );
        },
      ),
    );
  }
}

/// Widget to handle auto-login redirect
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Wait a bit for AuthService to initialize
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (!mounted) return;
    
    // Check if user is logged in
    if (AuthService.isLoggedIn) {
      // Check if user data is loaded
      if (AuthService.currentUser != null) {
        // Check if user is blocked
        if (AuthService.currentUser!['isBlocked'] == true) {
          // User is blocked, logout and go to login
          await AuthService.logout();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          }
        } else {
          // User is logged in and not blocked, redirect to home screen
          // Admin can access admin panel from Settings
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          }
        }
      } else {
        // User is authenticated but data not loaded yet, wait a bit more
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      // User is not logged in, go to login screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Đang kiểm tra...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }
    
    // Default to login screen if still here
    return const LoginScreen();
  }
}
