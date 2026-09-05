import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/navigation_provider.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safely initialize Firebase (graceful fallback if placeholder keys are active)
  try {
    final apiKey = DefaultFirebaseOptions.currentPlatform.apiKey;
    if (!apiKey.contains('PLACEHOLDER')) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint("[Firebase] Initialized with live project credentials.");
    } else {
      debugPrint("[Firebase] Running in placeholder mode. Real credentials can be added later in firebase_options.dart.");
    }
  } catch (e) {
    debugPrint("[Firebase] Setup note: $e (App running in local UI mode).");
  }

  runApp(const ShilpSetuApp());
}

class ShilpSetuApp extends StatelessWidget {
  const ShilpSetuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: MaterialApp(
        title: 'ShilpSetu - Artisan App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const MainScreen(),
      ),
    );
  }
}
