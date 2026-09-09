import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:frontend/screens/auth/language_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LanguageProvider Unit & Integration Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Supported languages are exactly 3: Hindi (hi), English (en), and Marathi (mr)', () {
      final supported = LanguageProvider.supportedLanguages;
      expect(supported.length, 3);
      final codes = supported.map((l) => l.code).toSet();
      expect(codes, containsAll(['hi', 'en', 'mr']));
    });

    test('Initial language defaults to Hindi (hi) if no cache present', () {
      final provider = LanguageProvider();
      expect(provider.currentLanguageCode, 'hi');
      expect(provider.getText('app_title'), 'शिल्पसेतु');
    });

    test('Switching to Marathi (mr) renders pure Marathi text without Hindi or English fallback', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('mr', updateFirestore: false);

      expect(provider.currentLanguageCode, 'mr');
      expect(provider.getText('app_title'), 'शिल्पसेतू');
      expect(provider.getText('choose_language'), 'तुमची भाषा निवडा');
      expect(provider.getText('tab_home'), 'मुख्य');
      expect(provider.getText('tab_products'), 'शिल्प सूची');
      expect(provider.getText('tab_orders'), 'ऑर्डर्स');
      expect(provider.getText('tab_profile'), 'प्रोफाइल');
      expect(provider.getText('role_artisan'), 'मी एक कारागीर आहे');
      expect(provider.getText('role_buyer'), 'मी एक खरेदीदार आहे');
      expect(provider.getText('catalog_title'), 'शिल्प सूची');
      expect(provider.getText('orders_title'), 'ऑर्डर्स');
      expect(provider.getText('add_product_title'), 'नवीन उत्पादन जोडा');
      expect(provider.getText('profile_title'), 'प्रोफाइल आणि भाषा');
      expect(provider.getText('sign_out_btn'), 'लॉग आउट');
    });

    test('Switching to English (en) renders pure English text', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('en', updateFirestore: false);

      expect(provider.currentLanguageCode, 'en');
      expect(provider.getText('app_title'), 'ShilpSetu');
      expect(provider.getText('choose_language'), 'Choose Your Language');
      expect(provider.getText('tab_home'), 'Home');
      expect(provider.getText('tab_products'), 'Catalog');
      expect(provider.getText('tab_orders'), 'Orders');
      expect(provider.getText('tab_profile'), 'Profile');
      expect(provider.getText('role_artisan'), 'I am an Artisan');
      expect(provider.getText('role_buyer'), 'I am a Buyer');
      expect(provider.getText('catalog_title'), 'Craft Catalog');
      expect(provider.getText('orders_title'), 'Orders');
      expect(provider.getText('add_product_title'), 'Add New Product');
      expect(provider.getText('profile_title'), 'Profile & Preferences');
      expect(provider.getText('sign_out_btn'), 'Log Out');
    });

    test('Switching to Hindi (hi) renders pure Hindi text', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('hi', updateFirestore: false);

      expect(provider.currentLanguageCode, 'hi');
      expect(provider.getText('app_title'), 'शिल्पसेतु');
      expect(provider.getText('choose_language'), 'अपनी भाषा चुनें');
      expect(provider.getText('tab_home'), 'होम');
      expect(provider.getText('tab_products'), 'शिल्प सूची');
      expect(provider.getText('tab_orders'), 'ऑर्डर्स');
      expect(provider.getText('tab_profile'), 'प्रोफ़ाइल');
      expect(provider.getText('role_artisan'), 'मैं एक शिल्पकार हूँ');
      expect(provider.getText('role_buyer'), 'मैं एक खरीदार हूँ');
      expect(provider.getText('catalog_title'), 'शिल्प सूची');
      expect(provider.getText('orders_title'), 'ऑर्डर्स');
      expect(provider.getText('add_product_title'), 'नया उत्पाद जोड़ें');
      expect(provider.getText('profile_title'), 'प्रोफ़ाइल एवं भाषा');
      expect(provider.getText('sign_out_btn'), 'लॉग आउट');
    });

    test('Language choice persists to SharedPreferences and recalls on app restart', () async {
      final provider = LanguageProvider();
      await provider.setLanguage('mr', updateFirestore: false);

      // Verify cached value in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language_preference'), 'mr');

      // Simulate app restart by creating a new LanguageProvider instance
      final restartedProvider = LanguageProvider();
      await restartedProvider.loadInitialLanguage();
      expect(restartedProvider.currentLanguageCode, 'mr');
      expect(restartedProvider.getText('tab_home'), 'मुख्य');
    });

    test('Multi-user independence: User 1 and User 2 language profiles do not collide', () {
      final provider = LanguageProvider();

      // User 1 logs in with Marathi preference
      provider.syncFromProfile('mr');
      expect(provider.currentLanguageCode, 'mr');
      expect(provider.getText('app_title'), 'शिल्पसेतू');

      // User 1 logs out and User 2 logs in with English preference
      provider.syncFromProfile('en');
      expect(provider.currentLanguageCode, 'en');
      expect(provider.getText('app_title'), 'ShilpSetu');

      // User 2 logs out and User 1 logs back in with Marathi preference
      provider.syncFromProfile('mr');
      expect(provider.currentLanguageCode, 'mr');
      expect(provider.getText('app_title'), 'शिल्पसेतू');
    });

    testWidgets('LanguageSelectionScreen displays exactly 3 languages and switches to Marathi', (tester) async {
      final langProvider = LanguageProvider();

      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: langProvider,
          child: const MaterialApp(
            home: LanguageSelectionScreen(),
          ),
        ),
      );

      // Verify language options exist
      expect(find.text('हिंदी'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('मराठी'), findsOneWidget);
      expect(find.text('Marathi'), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Tap on Marathi card
      await tester.tap(find.text('मराठी'));
      await tester.pumpAndSettle();

      expect(langProvider.currentLanguageCode, 'mr');
    });
  });
}
