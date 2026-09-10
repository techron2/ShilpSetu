import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LanguageOption {
  final String code;
  final String nameNative;
  final String nameEnglish;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.nameNative,
    required this.nameEnglish,
    required this.flag,
  });
}

class LanguageProvider extends ChangeNotifier {
  static const String _prefKey = 'app_language_preference';
  String _selectedLanguageCode = 'hi'; // Default Hindi

  String get currentLanguageCode => _selectedLanguageCode;

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(code: 'hi', nameNative: 'हिंदी', nameEnglish: 'Hindi', flag: '🇮🇳'),
    LanguageOption(code: 'en', nameNative: 'English', nameEnglish: 'English', flag: '🇬🇧'),
    LanguageOption(code: 'gu', nameNative: 'ગુજરાતી', nameEnglish: 'Gujarati', flag: '🇮🇳'),
    LanguageOption(code: 'mr', nameNative: 'मराठी', nameEnglish: 'Marathi', flag: '🇮🇳'),
    LanguageOption(code: 'bn', nameNative: 'বাংলা', nameEnglish: 'Bengali', flag: '🇮🇳'),
    LanguageOption(code: 'ta', nameNative: 'தமிழ்', nameEnglish: 'Tamil', flag: '🇮🇳'),
  ];

  LanguageProvider() {
    loadInitialLanguage();
  }

  /// Loads initial language preference from SharedPreferences on app startup.
  Future<void> loadInitialLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefKey);
      if (savedCode != null && supportedLanguages.any((l) => l.code == savedCode)) {
        _selectedLanguageCode = savedCode;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Sets the global language state, persists to SharedPreferences, and updates Firestore if signed in.
  Future<void> setLanguage(String code, {bool updateFirestore = true}) async {
    if (!supportedLanguages.any((l) => l.code == code)) return;

    _selectedLanguageCode = code;
    notifyListeners();

    // 1. Persist locally to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}

    // 2. Sync to Firestore if authenticated user exists
    if (updateFirestore) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'language_preference': code});
        }
      } catch (_) {}
    }
  }

  /// Syncs language from Firestore user profile if present.
  void syncFromProfile(String? languageCode) {
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        languageCode != _selectedLanguageCode &&
        supportedLanguages.any((l) => l.code == languageCode)) {
      setLanguage(languageCode, updateFirestore: false);
    }
  }

  /// Helper to fetch localized string by key
  String getText(String key) {
    final translations = _translations[_selectedLanguageCode] ?? _translations['hi']!;
    return translations[key] ?? _translations['en']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'hi': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'हस्तशिल्प को दुनिया से जोड़ना',
      'choose_language': 'अपनी भाषा चुनें',
      'choose_language_sub': 'आगे बढ़ने के लिए अपनी पसंदीदा भाषा चुनें',
      'continue': 'आगे बढ़ें (Continue)',
      'signup_title': 'खाता बनाएं',
      'step_1_sub': 'चरण 1/2 — विवरण दर्ज करें',
      'full_name': 'पूरा नाम',
      'email': 'ईमेल पता',
      'password': 'पासवर्ड',
      'phone': 'फ़ोन नंबर',
      'next_role': 'अगला: भूमिका चुनें',
      'already_have_account': 'पहले से खाता है? लॉग इन करें',
      'login_title': 'KalaVistar में आपका स्वागत है',
      'login_sub': 'हस्तशिल्प को दुनिया से जोड़ना',
      'forgot_password': 'पासवर्ड भूल गए?',
      'login_btn': 'लॉग इन करें',
      'create_account_btn': 'नया खाता बनाएं',
      'email_login': 'ईमेल लॉगिन',
      'phone_login': 'फ़ोन नंबर लॉगिन',
      'send_otp': 'OTP भेजें',
      'enter_otp': '6-अंकों का OTP दर्ज करें',
      'verify_otp': 'सत्यापित करें और लॉग इन करें',
      'reset_title': 'पासवर्ड रीसेट करें',
      'reset_sub': 'अपना पंजीकृत ईमेल दर्ज करें',
      'send_reset_link': 'रीसेट लिंक भेजें',
      'reset_sent_msg': 'आपके ईमेल पर रीसेट लिंक भेज दिया गया है!',

      // Role Selection
      'role_title': 'आपकी क्या भूमिका है?',
      'role_sub': 'KalaVistar पर आप क्या करना चाहते हैं?',
      'role_artisan': 'मैं एक कारीगर हूँ (Artisan)',
      'role_artisan_desc': 'अपने शिल्पों को सूचीबद्ध करें, ऑनलाइन ऑर्डर प्राप्त करें और बिक्री बढ़ाएं',
      'role_buyer': 'मैं एक खरीदार / व्यापारी हूँ (Buyer)',
      'role_buyer_desc': 'प्रमाणित कारीगरों से सीधे हस्तशिल्प खरीदें और थोक ऑर्डर दें',

      // Navigation Tabs
      'tab_home': 'गृह (Home)',
      'tab_products': 'उत्पाद (Products)',
      'tab_orders': 'ऑर्डर (Orders)',
      'tab_profile': 'प्रोफ़ाइल (Profile)',
      'tab_discover': 'खोजें (Discover)',

      // Main / Dashboard Screen
      'greeting_artisan': 'नमस्ते, कारीगर जी!',
      'greeting_buyer': 'नमस्ते, स्वागत है!',
      'voice_assistant_btn': '🎙️ बोलकर व्यापार सहायक से बात करें',
      'quick_actions': 'त्वरित कार्य (Quick Actions)',
      'add_new_product': 'नया उत्पाद जोड़ें',
      'view_analytics': 'बिजनेस एनालिटिक्स',
      'business_counselor': 'AI व्यापार सलाहकार',
      'virtual_clusters': 'वर्चुअल क्लस्टर समूह',
      'recent_products': 'आपके हालिया उत्पाद',

      // Products / Catalog
      'my_products_title': 'मेरे उत्पाद',
      'no_products': 'अभी कोई उत्पाद सूचीबद्ध नहीं है',
      'add_first_product': 'अपना पहला उत्पाद जोड़ें',
      'price_currency': '₹',
      'stock_available': 'उपलब्ध',

      // Add Product Flow
      'add_product_title': 'नया उत्पाद जोड़ें',
      'product_name_label': 'उत्पाद का नाम',
      'product_category_label': 'श्रेणी (Category)',
      'product_price_label': 'मूल्य (₹)',
      'product_stock_label': 'स्टॉक मात्रा',
      'product_desc_label': 'उत्पाद विवरण (कहानी/शिल्प विधि)',
      'take_photo_btn': '📷 फोटो खींचें / AI Studio पॉलिश करें',
      'record_voice_btn': '🎙️ बोलकर विवरण दर्ज करें (Voice Input)',
      'submit_product_btn': 'उत्पाद प्रकाशित करें',

      // Profile Screen
      'profile_title': 'प्रोफ़ाइल एवं भाषा',
      'app_language_heading': 'ऐप की भाषा (App Language)',
      'sign_out_btn': 'साइन आउट (Sign Out)',
      'account_type': 'खाता प्रकार',
      'contact_info': 'संपर्क विवरण',
    },
    'en': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'Connecting artisans to the world',
      'choose_language': 'Choose Your Language',
      'choose_language_sub': 'Select your preferred language to continue',
      'continue': 'Continue',
      'signup_title': 'Create Account',
      'step_1_sub': 'Step 1 of 2 — Enter your details',
      'full_name': 'Full Name',
      'email': 'Email Address',
      'password': 'Password',
      'phone': 'Phone Number',
      'next_role': 'Next: Choose Role',
      'already_have_account': 'Already have an account? Log In',
      'login_title': 'Welcome to KalaVistar',
      'login_sub': 'Connecting artisans to the world',
      'forgot_password': 'Forgot Password?',
      'login_btn': 'Log In',
      'create_account_btn': 'Create New Account',
      'email_login': 'Email Login',
      'phone_login': 'Phone Number Login',
      'send_otp': 'Send OTP',
      'enter_otp': 'Enter 6-digit OTP',
      'verify_otp': 'Verify & Log In',
      'reset_title': 'Reset Password',
      'reset_sub': 'Enter your registered email address',
      'send_reset_link': 'Send Reset Link',
      'reset_sent_msg': 'Password reset link sent! Check your inbox.',

      // Role Selection
      'role_title': 'Choose Your Role',
      'role_sub': 'What would you like to do on KalaVistar?',
      'role_artisan': 'I am an Artisan',
      'role_artisan_desc': 'List your crafts, receive direct orders, and grow your business',
      'role_buyer': 'I am a Buyer / Merchant',
      'role_buyer_desc': 'Source authentic crafts directly from verified artisan clusters',

      // Navigation Tabs
      'tab_home': 'Home',
      'tab_products': 'Products',
      'tab_orders': 'Orders',
      'tab_profile': 'Profile',
      'tab_discover': 'Discover',

      // Main / Dashboard Screen
      'greeting_artisan': 'Hello, Artisan!',
      'greeting_buyer': 'Welcome, Buyer!',
      'voice_assistant_btn': '🎙️ Speak with AI Business Assistant',
      'quick_actions': 'Quick Actions',
      'add_new_product': 'Add New Product',
      'view_analytics': 'Business Analytics',
      'business_counselor': 'AI Business Assistant',
      'virtual_clusters': 'Virtual Clusters',
      'recent_products': 'Your Recent Products',

      // Products / Catalog
      'my_products_title': 'My Products',
      'no_products': 'No products listed yet',
      'add_first_product': 'Add Your First Product',
      'price_currency': '₹',
      'stock_available': 'available',

      // Add Product Flow
      'add_product_title': 'Add New Product',
      'product_name_label': 'Product Title',
      'product_category_label': 'Category',
      'product_price_label': 'Price (₹)',
      'product_stock_label': 'Stock Quantity',
      'product_desc_label': 'Product Story / Craft Method',
      'take_photo_btn': '📷 Capture Photo / AI Studio Polish',
      'record_voice_btn': '🎙️ Record Story via Voice Input',
      'submit_product_btn': 'Publish Product Listing',

      // Profile Screen
      'profile_title': 'Profile & Preferences',
      'app_language_heading': 'App Language',
      'sign_out_btn': 'Sign Out',
      'account_type': 'Account Type',
      'contact_info': 'Contact Info',
    },
    'gu': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'કારીગરોને વિશ્વ સાથે જોડવું',
      'choose_language': 'તમારી ભાષા પસંદ કરો',
      'choose_language_sub': 'આગળ વધવા માટે તમારી ભાષા પસંદ કરો',
      'continue': 'આગળ વધો',
      'signup_title': 'ખાતું બનાવો',
      'step_1_sub': 'પગલું 1/2 — તમારી વિગતો ભરો',
      'full_name': 'પૂરું નામ',
      'email': 'ઈમેલ સરનામું',
      'password': 'પાસવર્ડ',
      'phone': 'ફોન નંબર',
      'next_role': 'આગળ: ભૂમિકા પસંદ કરો',
      'already_have_account': 'એકાઉન્ટ છે? લોગ ઈન કરો',
      'login_title': 'KalaVistarમાં આપનું સ્વાગત છે',
      'login_sub': 'કારીગરોને વિશ્વ સાથે જોડવું',
      'forgot_password': 'પાસવર્ડ ભૂલી ગયા છો?',
      'login_btn': 'લોગ ઇન કરો',
      'create_account_btn': 'નવું એકાઉન્ટ બનાવો',
      'email_login': 'ઈમેલ લોગિન',
      'phone_login': 'ફોન લોગિન',
      'send_otp': 'OTP મોકલો',
      'enter_otp': '6-અંકનો OTP દાખલ કરો',
      'verify_otp': 'ચકાસો અને લોગ ઇન કરો',
      'reset_title': 'પાસવર્ડ રિસેટ કરો',
      'reset_sub': 'તમારું ઇમેઇલ દાખલ કરો',
      'send_reset_link': 'રિસેટ લિંક મોકલો',
      'reset_sent_msg': 'રિસેટ લિંક ઇમેઇલ પર મોકલવામાં આવી છે!',

      // Role Selection
      'role_title': 'તમારી ભૂમિકા પસંદ કરો',
      'role_sub': 'તમે KalaVistar પર શું કરવા માંગો છો?',
      'role_artisan': 'હું એક કારીગર છું',
      'role_artisan_desc': 'તમારી બનાવટો ઉમેરો અને ઓર્ડર મેળવો',
      'role_buyer': 'હું એક ખરીદદાર છું',
      'role_buyer_desc': 'સીધા જ કારીગરો પાસેથી ખરીદી કરો',

      // Navigation Tabs
      'tab_home': 'હોમ',
      'tab_products': 'પ્રોડક્ટ્સ',
      'tab_orders': 'ઓર્ડર્સ',
      'tab_profile': 'પ્રોફાઇલ',
      'tab_discover': 'શોધો',

      // Main / Dashboard Screen
      'greeting_artisan': 'નમસ્તે, કારીગર જી!',
      'greeting_buyer': 'નમસ્તે, સ્વાગત છે!',
      'voice_assistant_btn': '🎙️ વૉઇસ બિઝનેસ સહાયક',
      'quick_actions': 'ઝડપી કાર્યો',
      'add_new_product': 'નવી પ્રોડક્ટ ઉમેરો',
      'view_analytics': 'બિઝનેસ એનાલિટિક્સ',
      'business_counselor': 'AI બિઝનેસ સહાયક',
      'virtual_clusters': 'વર્ચ્યુઅલ ક્લસ્ટર જૂથો',
      'recent_products': 'તમારી તાજેતરની પ્રોડક્ટ્સ',

      // Profile Screen
      'profile_title': 'પ્રોફાઇલ અને ભાષા',
      'app_language_heading': 'એપ્લિકેશન ભાષા',
      'sign_out_btn': 'સાઇન આઉટ',
      'account_type': 'એકાઉન્ટ પ્રકાર',
      'contact_info': 'સંપર્ક વિગતો',
    },
    'mr': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'कारागिरांना जगाशी जोडणे',
      'choose_language': 'तुमची भाषा निवडा',
      'choose_language_sub': 'पुढे जाण्यासाठी तुमची आवडती भाषा निवडा',
      'continue': 'पुढे जा',
      'signup_title': 'खाते तयार करा',
      'step_1_sub': 'टप्पा 1/2 — तुमचा तपशील भरा',
      'full_name': 'पूर्ण नाव',
      'email': 'ईमेल पत्ता',
      'password': 'पासवर्ड',
      'phone': 'फोन नंबर',
      'next_role': 'पुढील: भूमिका निवडा',
      'already_have_account': 'आधीच खाते आहे? लॉग इन करा',
      'login_title': 'KalaVistarमध्ये आपले स्वागत आहे',
      'login_sub': 'कारागिरांना जगाशी जोडणे',
      'forgot_password': 'पासवर्ड विसरलात?',
      'login_btn': 'लॉग इन करा',
      'create_account_btn': 'नवीन खाते तयार करा',
      'email_login': 'ईमेल लॉगिन',
      'phone_login': 'फोन लॉगिन',
      'send_otp': 'OTP पाठवा',
      'enter_otp': '6-अंकी OTP टाका',
      'verify_otp': 'सत्यापित करा आणि लॉगिन करा',
      'reset_title': 'पासवर्ड रीसेट करा',
      'reset_sub': 'तुमचा नोंदणीकृत ईमेल प्रविष्ट करा',
      'send_reset_link': 'रीसेट लिंक पाठवा',
      'reset_sent_msg': 'ईमेलवर रीसेट लिंक पाठवली आहे!',

      // Role Selection
      'role_title': 'तुमची भूमिका निवडा',
      'role_sub': 'तुम्ही KalaVistarवर काय करू इच्छिता?',
      'role_artisan': 'मी एक कारागीर आहे',
      'role_artisan_desc': 'तुमच्या वस्तू सूचीबद्ध करा आणि ऑर्डर मिळवा',
      'role_buyer': 'मी एक खरेदीदार आहे',
      'role_buyer_desc': 'थेट कारागिरांकडून वस्तू खरेदी करा',

      // Navigation Tabs
      'tab_home': 'मुख्य',
      'tab_products': 'उत्पादने',
      'tab_orders': 'ऑर्डर्स',
      'tab_profile': 'प्रोफाइल',
      'tab_discover': 'शोधा',

      // Main / Dashboard Screen
      'greeting_artisan': 'नमस्कार, कारागीर जी!',
      'greeting_buyer': 'नमस्कार, स्वागत आहे!',
      'voice_assistant_btn': '🎙️ व्हॉइस व्यवसाय सहाय्यक',
      'quick_actions': 'जलद कृती',
      'add_new_product': 'नवीन उत्पादन जोडा',
      'view_analytics': 'व्यवसाय विश्लेषण',
      'business_counselor': 'AI व्यवसाय सल्लागार',
      'virtual_clusters': 'व्हर्च्युअल क्लस्टर गट',
      'recent_products': 'तुमची अलीकडील उत्पादने',

      // Profile Screen
      'profile_title': 'प्रोफाइल आणि भाषा',
      'app_language_heading': 'अॅप भाषा',
      'sign_out_btn': 'साइन आउट',
      'account_type': 'खाते प्रकार',
      'contact_info': 'संपर्क माहिती',
    },
    'bn': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'কারিগরদের বিশ্বের সাথে সংযুক্ত করা',
      'choose_language': 'আপনার ভাষা নির্বাচন করুন',
      'choose_language_sub': 'চালিয়ে যেতে আপনার পছন্দের ভাষা চয়ন করুন',
      'continue': 'এগিয়ে যান',
      'signup_title': 'অ্যাকাউন্ট তৈরি করুন',
      'step_1_sub': 'ধাপ ১/২ — বিবরণ দিন',
      'full_name': 'সম্পূর্ণ নাম',
      'email': 'ইমেল ঠিকানা',
      'password': 'পাসওয়ার্ড',
      'phone': 'ফোন নম্বর',
      'next_role': 'পরবর্তী: ভূমিকা চয়ন করুন',
      'already_have_account': 'অ্যাকাউন্ট আছে? লগ ইন করুন',
      'login_title': 'KalaVistarতে স্বাগতম',
      'login_sub': 'কারিগরদের বিশ্বের সাথে সংযুক্ত করা',
      'forgot_password': 'পাসওয়ার্ড ভুলে গেছেন?',
      'login_btn': 'লগ ইন করুন',
      'create_account_btn': 'নতুন অ্যাকাউন্ট তৈরি করুন',
      'email_login': 'ইমেল লগইন',
      'phone_login': 'ফোন নম্বর লগইন',
      'send_otp': 'OTP পাঠান',
      'enter_otp': '৬-সংখ্যার OTP লিখুন',
      'verify_otp': 'যাচাই করুন এবং লগ ইন করুন',
      'reset_title': 'পাসওয়ার্ড রিসেট করুন',
      'reset_sub': 'আপনার ইমেল লিখুন',
      'send_reset_link': 'রিসেট লিঙ্ক পাঠান',
      'reset_sent_msg': 'ইমেলে রিসেট লিঙ্ক পাঠানো হয়েছে!',

      // Role Selection
      'role_title': 'আপনার ভূমিকা চয়ন করুন',
      'role_sub': 'আপনি KalaVistarতে কী করতে চান?',
      'role_artisan': 'আমি একজন কারিগর',
      'role_artisan_desc': 'আপনার তৈরি পণ্য তালিকাভুক্ত করুন ও অর্ডার পান',
      'role_buyer': 'আমি একজন ক্রেতা',
      'role_buyer_desc': 'সরাসরি কারিগরদের থেকে কেনাকাটা করুন',

      // Navigation Tabs
      'tab_home': 'হোম',
      'tab_products': 'পণ্য',
      'tab_orders': 'অর্ডার',
      'tab_profile': 'প্রোফাইল',
      'tab_discover': 'আবিষ্কার করুন',

      // Main / Dashboard Screen
      'greeting_artisan': 'নমস্কার, কারিগর জি!',
      'greeting_buyer': 'নমস্কার, স্বাগতম!',
      'voice_assistant_btn': '🎙️ ভয়েস বিজনেস অ্যাসিস্ট্যান্ট',
      'quick_actions': 'দ্রুত কাজ',
      'add_new_product': 'নতুন পণ্য যোগ করুন',
      'view_analytics': 'ব্যবসার অ্যানালিটিক্স',
      'business_counselor': 'AI ব্যবসায়িক উপদেষ্টা',
      'virtual_clusters': 'ভার্চুয়াল ক্লাস্টার গ্রুপ',
      'recent_products': 'আপনার সাম্প্রতিক পণ্য',

      // Profile Screen
      'profile_title': 'প্রোফাইল এবং ভাষা',
      'app_language_heading': 'অ্যাপের ভাষা',
      'sign_out_btn': 'সাইন আউট',
      'account_type': 'অ্যাকাউন্টের ধরন',
      'contact_info': 'যোগাযোগের তথ্য',
    },
    'ta': {
      'app_title': 'KalaVistar',
      'app_subtitle': 'கைவினைஞர்களை உலகத்துடன் இணைக்கிறது',
      'choose_language': 'உங்கள் மொழியைத் தேர்ந்தெடுக்கவும்',
      'choose_language_sub': 'தொடர உங்கள் விருப்பமான மொழியைத் தேர்ந்தெடுக்கவும்',
      'continue': 'தொடரவும்',
      'signup_title': 'கணக்கை உருவாக்கவும்',
      'step_1_sub': 'படி 1/2 — விவரங்களை உள்ளிடவும்',
      'full_name': 'முழு பெயர்',
      'email': 'மின்னஞ்சல்',
      'password': 'கடவுச்சொல்',
      'phone': 'தொலைபேசி எண்',
      'next_role': 'அடுத்து: பாத்திரத்தைத் தேர்வுசெய்க',
      'already_have_account': 'கணக்கு உள்ளதா? உள்நுழையவும்',
      'login_title': 'KalaVistarற்கு வரவேற்கிறோம்',
      'login_sub': 'கைவினைஞர்களை உலகத்துடன் இணைக்கிறது',
      'forgot_password': 'கடவுச்சொல்லை மறந்துவிட்டீர்களா?',
      'login_btn': 'உள்நுழையவும்',
      'create_account_btn': 'புதிய கணக்கை உருவாக்கவும்',
      'email_login': 'மின்னஞ்சல் உள்நுழைவு',
      'phone_login': 'தொலைபேசி உள்நுழைவு',
      'send_otp': 'OTP அனுப்புக',
      'enter_otp': '6 இலக்க OTP ஐ உள்ளிடவும்',
      'verify_otp': 'சரிபார்த்து உள்நுழையவும்',
      'reset_title': 'கடவுச்சொல்லை மீட்டமைக்கவும்',
      'reset_sub': 'உங்கள் மின்னஞ்சலை உள்ளிடவும்',
      'send_reset_link': 'மீட்டமைப்பு இணைப்பை அனுப்புக',
      'reset_sent_msg': 'மீட்டமைப்பு இணைப்பு மின்னஞ்சலுக்கு அனுப்பப்பட்டது!',

      // Role Selection
      'role_title': 'உங்கள் பாத்திரத்தைத் தேர்ந்தெடுக்கவும்',
      'role_sub': 'KalaVistarல் நீங்கள் என்ன செய்ய விரும்புகிறீர்கள்?',
      'role_artisan': 'நான் ஒரு கைவினைஞர்',
      'role_artisan_desc': 'உங்கள் கைவினைப் பொருட்களைப் பட்டியலிட்டு ஆர்டர்களைப் பெறுங்கள்',
      'role_buyer': 'நான் ஒரு வாடிக்கையாளர்',
      'role_buyer_desc': 'நேரடியாக கைவினைஞர்களிடமிருந்து வாங்குங்கள்',

      // Navigation Tabs
      'tab_home': 'முகப்பு',
      'tab_products': 'பொருட்கள்',
      'tab_orders': 'ஆர்டர்கள்',
      'tab_profile': 'சுயவிவரம்',
      'tab_discover': 'கண்டறியவும்',

      // Main / Dashboard Screen
      'greeting_artisan': 'வணக்கம், கைவினைஞரே!',
      'greeting_buyer': 'வணக்கம், வருக!',
      'voice_assistant_btn': '🎙️ குரல் வணிக உதவியாளர்',
      'quick_actions': 'விரைவு እርμவடிக்கைகள்',
      'add_new_product': 'புதிய பொருளைச் சேர்க்கவும்',
      'view_analytics': 'வணிக பகுப்பாய்வு',
      'business_counselor': 'AI வணிக ஆலோசகர்',
      'virtual_clusters': 'மெய்நிகர் கிளஸ்டர்கள்',
      'recent_products': 'உங்கள் சமீபத்திய பொருட்கள்',

      // Profile Screen
      'profile_title': 'சுயவிவரம் & மொழி',
      'app_language_heading': 'செயலி மொழி',
      'sign_out_btn': 'வெளியேறு',
      'account_type': 'கணக்கு வகை',
      'contact_info': 'தொடர்பு விவரங்கள்',
    },
  };
}
