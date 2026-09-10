import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'firebase_options.dart';
import 'providers/navigation_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/language_provider.dart';
import 'screens/main_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AppAuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        title: 'KalaVistar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

/// Backwards-compatible alias for ShilpSetuApp
typedef ShilpSetuApp = MyApp;

/// Canonical product brand alias
typedef KalaVistarApp = MyApp;

/// Top-level single source of truth for authentication state.
///
/// Listens directly to [FirebaseAuth.instance.authStateChanges()].
/// - If authenticated: ensures navigation resets to Home tab (index 0) and renders [MainScreen].
/// - If unauthenticated: renders [AuthWrapper] which toggles between [LoginScreen]
///   and [SignupScreen] at the root level without stacking separate routes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.bgParchment,
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primaryTerracotta),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // Reset navigation tab to Home (0) and sync language preference from profile
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.read<NavigationProvider>().setIndex(0);
              final authUser = context.read<AppAuthProvider>().userModel;
              if (authUser != null) {
                context.read<LanguageProvider>().syncFromProfile(authUser.languagePreference);
              }
            }
          });
          return const MainScreen();
        } else {
          return const AuthWrapper();
        }
      },
    );
  }
}

/// Root-level toggle between [LoginScreen] and [SignupScreen].
/// Prevents pushing separate modal routes onto the Navigator stack.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _showLogin = true;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _showLogin
          ? LoginScreen(
              key: const ValueKey('LoginScreen'),
              onSwitchToSignUp: () => setState(() => _showLogin = false),
            )
          : SignupScreen(
              key: const ValueKey('SignupScreen'),
              onSwitchToLogin: () => setState(() => _showLogin = true),
            ),
    );
  }
}
