import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Passport and buyer role copy stay evidence-neutral in all supported languages', () async {
    final language = LanguageProvider();
    addTearDown(language.dispose);

    for (final code in ['en', 'hi', 'mr']) {
      await language.setLanguage(code, updateFirestore: false);
      final passport = language.getText('banner_passport_desc');
      final buyerRole = language.getText('role_buyer_desc');
      final combined = '$passport $buyerRole'.toLowerCase();

      expect(passport, isNotEmpty);
      expect(buyerRole, isNotEmpty);
      expect(combined, isNot(contains('tamper-proof')));
      expect(combined, isNot(contains('authenticity verification')));
      expect(combined, isNot(contains('certificate')));
      expect(combined, isNot(contains('verified')));
      expect(combined, isNot(contains('certified')));
      expect(combined, isNot(contains('प्रमाणित')));
      expect(combined, isNot(contains('प्रामाणिकता प्रमाण')));
      expect(combined, isNot(contains('अस्सलतेचे प्रमाणपत्र')));
      if (code == 'en') {
        expect(passport, contains('recorded'));
        expect(passport, contains('when available'));
        expect(buyerRole, contains('artisans'));
      } else {
        expect(passport, contains('उपलब्ध'));
      }
    }

    await language.setLanguage('en', updateFirestore: false);
    expect(
      language.getText('banner_passport_desc'),
      'Share recorded artisan, craft and origin details with buyers when available.',
    );
    await language.setLanguage('hi', updateFirestore: false);
    expect(
      language.getText('banner_passport_desc'),
      'उपलब्ध होने पर दर्ज कारीगर, शिल्प और क्षेत्र की जानकारी खरीदारों के साथ साझा करें।',
    );
    await language.setLanguage('mr', updateFirestore: false);
    expect(
      language.getText('banner_passport_desc'),
      'उपलब्ध असल्यास नोंदवलेली कारागीर, हस्तकला आणि प्रदेशाची माहिती खरेदीदारांसोबत शेअर करा.',
    );
  });
}
