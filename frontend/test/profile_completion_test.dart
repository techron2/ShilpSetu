import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/providers/navigation_provider.dart';
import 'package:frontend/providers/product_provider.dart';
import 'package:frontend/screens/artisan/profile_completion_screen.dart';
import 'package:frontend/screens/profile_screen.dart';

Widget _buildTestWidget({
  required Widget child,
  LanguageProvider? lang,
  UserModel? user,
}) {
  final authProvider = AppAuthProvider();
  if (user != null) {
    authProvider.updateUserModel(user);
  }

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider<AppAuthProvider>.value(value: authProvider),
      ChangeNotifierProvider(create: (_) => ProductProvider()),
      ChangeNotifierProvider(create: (_) => lang ?? LanguageProvider()),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 1600)),
        child: child,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Completion Screen Tests', () {
    testWidgets('Renders Step 0 (Basic Info) with voice banner and fields', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lang = LanguageProvider();
      await lang.setLanguage('en', updateFirestore: false);

      await tester.pumpWidget(_buildTestWidget(
        child: const ProfileCompletionScreen(),
        lang: lang,
      ));
      await tester.pumpAndSettle();

      // Header & Stepper
      expect(find.text(lang.getText('profile_completion_title')), findsWidgets);
      expect(find.text(lang.getText('step_basic_info')), findsOneWidget);

      // Voice fill banner
      expect(find.text(lang.getText('voice_fill_banner_title')), findsOneWidget);
      expect(find.text(lang.getText('voice_fill_btn')), findsOneWidget);

      // Step 0 Fields
      expect(find.text(lang.getText('full_name')), findsWidgets);
      expect(find.text(lang.getText('dob_label')), findsOneWidget);
      expect(find.text(lang.getText('phone')), findsWidgets);
    });

    testWidgets('Step navigation moves from Step 0 through Step 3', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lang = LanguageProvider();
      await lang.setLanguage('en', updateFirestore: false);

      await tester.pumpWidget(_buildTestWidget(
        child: const ProfileCompletionScreen(),
        lang: lang,
      ));
      await tester.pumpAndSettle();

      // Step 0 -> Step 1 (Personal Info)
      final nextBtn1 = find.widgetWithText(ElevatedButton, lang.getText('next_btn'));
      expect(nextBtn1, findsOneWidget);
      await tester.tap(nextBtn1);
      await tester.pumpAndSettle();

      expect(find.text(lang.getText('gender_label')), findsOneWidget);
      expect(find.text(lang.getText('marital_status_label')), findsOneWidget);
      expect(find.text(lang.getText('experience_years_label')), findsOneWidget);

      // Step 1 -> Step 2 (Photos)
      final nextBtn2 = find.widgetWithText(ElevatedButton, lang.getText('next_btn'));
      expect(nextBtn2, findsOneWidget);
      await tester.tap(nextBtn2);
      await tester.pumpAndSettle();

      expect(find.text(lang.getText('profile_photo_label')), findsOneWidget);
      expect(find.text(lang.getText('cover_photo_label')), findsOneWidget);

      // Step 2 -> Step 3 (Story)
      final nextBtn3 = find.widgetWithText(ElevatedButton, lang.getText('next_btn'));
      expect(nextBtn3, findsOneWidget);
      await tester.tap(nextBtn3);
      await tester.pumpAndSettle();

      expect(find.text(lang.getText('story_field_label')), findsOneWidget);
      expect(find.text(lang.getText('save_profile_btn')), findsOneWidget);
    });

    testWidgets('initialStep opens directly into the specified step (e.g. initialStep: 3)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lang = LanguageProvider();
      await lang.setLanguage('hi', updateFirestore: false);

      await tester.pumpWidget(_buildTestWidget(
        child: const ProfileCompletionScreen(initialStep: 3),
        lang: lang,
      ));
      await tester.pumpAndSettle();

      // Should directly show Story fields
      expect(find.text(lang.getText('story_field_label')), findsOneWidget);
      expect(find.text(lang.getText('save_profile_btn')), findsOneWidget);
    });
  });

  group('Profile Screen Artisan Story Expansion Tests', () {
    testWidgets('Artisan Story expands and collapses smoothly with Read more / Show less', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lang = LanguageProvider();
      await lang.setLanguage('en', updateFirestore: false);

      const longStory = 'I have been practicing the art of handcrafted terracotta pottery for over 22 years in my ancestral village. Every vase, pot, and diya is shaped with indigenous clay using a traditional hand-turned wheel, and fired using natural kiln wood. My grandfather taught me this sacred craft when I was just 8 years old.';

      final artisan = UserModel(
        uid: 'artisan_test_123',
        name: 'Ramesh Patel',
        email: 'ramesh@example.com',
        phone: '9876543210',
        role: 'artisan',
        artisanStory: longStory,
        experienceYears: 22,
        gender: 'Male',
        maritalStatus: 'Married',
        dateOfBirth: '1985-06-15',
      );

      await tester.pumpWidget(_buildTestWidget(
        child: const ProfileScreen(),
        lang: lang,
        user: artisan,
      ));
      await tester.pumpAndSettle();

      // Heading and initial state
      expect(find.text(lang.getText('artisan_story_title')), findsWidgets);
      expect(find.text(lang.getText('read_more')), findsOneWidget);
      expect(find.text(lang.getText('show_less')), findsNothing);

      // Tap 'Read more' to expand
      await tester.tap(find.text(lang.getText('read_more')));
      await tester.pumpAndSettle();

      // Now 'Show less' should be visible
      expect(find.text(lang.getText('show_less')), findsOneWidget);
      expect(find.text(lang.getText('read_more')), findsNothing);

      // Tap 'Show less' to collapse back
      await tester.tap(find.text(lang.getText('show_less')));
      await tester.pumpAndSettle();

      expect(find.text(lang.getText('read_more')), findsOneWidget);
      expect(find.text(lang.getText('show_less')), findsNothing);
    });

    testWidgets('Artisan Story in Marathi (mr) renders pure Marathi without language mixing', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final lang = LanguageProvider();
      await lang.setLanguage('mr', updateFirestore: false);

      const mrStory = 'मी गेल्या १५ वर्षांपासून पैठणी साडी विणकाम करत आहे. माझी कला ही माझ्या पूर्वजांची देणगी आहे आणि मी प्रत्येक साडी अत्यंत प्रेमाने आणि एकाग्रतेने विणतो.';

      final artisan = UserModel(
        uid: 'artisan_mr_123',
        name: 'दत्तात्रय जोशी',
        email: 'dattatray@example.com',
        phone: '9123456789',
        role: 'artisan',
        artisanStory: mrStory,
      );

      await tester.pumpWidget(_buildTestWidget(
        child: const ProfileScreen(),
        lang: lang,
        user: artisan,
      ));
      await tester.pumpAndSettle();

      expect(find.text('कारागिराची गोष्ट'), findsWidgets);
      expect(find.text(lang.getText('read_more')), findsOneWidget);
      expect(find.text('पूर्ण वाचा'), findsOneWidget);
    });
  });
}
