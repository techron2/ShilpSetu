import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
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
    LanguageOption(code: 'mr', nameNative: 'मराठी', nameEnglish: 'Marathi', flag: '🇮🇳'),
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

    // 2. Sync to Firestore if authenticated user exists and Firebase is initialized
    if (updateFirestore && Firebase.apps.isNotEmpty) {
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

  /// Loads language preference from Firestore document for a specific user.
  Future<void> loadLanguageForUser(String uid) async {
    if (Firebase.apps.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final code = doc.data()?['language_preference']?.toString();
        if (code != null && supportedLanguages.any((l) => l.code == code)) {
          await setLanguage(code, updateFirestore: false);
        }
      }
    } catch (_) {}
  }

  /// Helper to fetch localized string by key.
  String getText(String key) {
    final translations = _translations[_selectedLanguageCode] ?? _translations['hi']!;
    return translations[key] ?? _translations['en']?[key] ?? _translations['hi']?[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    // ═════════════════════════════════════════════════════════════════════════
    // HINDI (hi)
    // ═════════════════════════════════════════════════════════════════════════
    'hi': {
      // App Branding & General
      'app_title': 'शिल्पसेतु',
      'app_tagline': 'परंपरा • शिल्प • कल',
      'app_subtitle': 'हस्तशिल्प को दुनिया से जोड़ना',
      'see_all': 'सभी देखें',
      'price_currency': '₹',
      'continue': 'आगे बढ़ें',

      // Language Selection
      'choose_language': 'अपनी भाषा चुनें',
      'choose_language_sub': 'आगे बढ़ने के लिए अपनी पसंदीदा भाषा चुनें',

      // Authentication (Signup & Login)
      'signup_title': 'खाता बनाएं',
      'step_1_sub': 'चरण 1/2 — विवरण दर्ज करें',
      'step_2_sub': 'चरण 2/2 — अपनी भूमिका चुनें',
      'full_name': 'पूरा नाम',
      'email': 'ईमेल पता',
      'password': 'पासवर्ड',
      'phone': 'फ़ोन नंबर',
      'next_role': 'अगला: भूमिका चुनें',
      'already_have_account': 'पहले से खाता है? लॉग इन करें',
      'login_title': 'शिल्पसेतु में आपका स्वागत है',
      'login_sub': 'हस्तशिल्प को दुनिया से जोड़ना',
      'forgot_password': 'पासवर्ड भूल गए?',
      'login_btn': 'लॉग इन करें',
      'create_account_btn': 'नया खाता बनाएं',
      'create_my_account_btn': 'मेरा खाता बनाएं',
      'role_change_note': 'आप बाद में प्रोफ़ाइल में अपनी भूमिका बदल सकते हैं।',
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
      'role_sub': 'शिल्पसेतु पर आप क्या करना चाहते हैं?',
      'role_artisan': 'मैं एक शिल्पकार हूँ',
      'role_artisan_desc': 'अपने शिल्पों को सूचीबद्ध करें, सीधे ऑर्डर प्राप्त करें और बिक्री बढ़ाएं',
      'role_buyer': 'मैं एक खरीदार हूँ',
      'role_buyer_desc': 'प्रमाणित कारीगरों से सीधे हस्तशिल्प खरीदें और थोक ऑर्डर दें',

      // Navigation Tabs & Screen Titles
      'tab_home': 'होम',
      'tab_products': 'शिल्प सूची',
      'tab_orders': 'ऑर्डर्स',
      'tab_profile': 'प्रोफ़ाइल',
      'tab_discover': 'खोजें',
      'tab_rfq': 'कोटेशन',
      'buyer_rfq_title': 'कोटेशन अनुरोध',
      'title_home': 'शिल्पसेतु • होम',
      'title_catalog': 'शिल्प सूची',
      'title_orders': 'ऑर्डर्स व डिलीवरी',
      'title_profile': 'शिल्पकार प्रोफ़ाइल',

      // Artisan Home Screen
      'greeting_artisan': 'नमस्ते, कारीगर जी!',
      'greeting_buyer': 'नमस्ते, स्वागत है!',
      'home_greeting_prefix': 'नमस्ते',
      'home_overview_subtitle': 'आपका दैनिक शिल्प व्यापार सारांश',
      'banner_sell_title': 'अपना शिल्प बेचें',
      'banner_sell_desc': 'देश भर के खरीदारों से सीधे जुड़ें और अपनी कला का सही मूल्य पाएं',
      'banner_sell_cta': 'शुरू करें',
      'banner_cluster_title': 'कारीगर क्लस्टर',
      'banner_cluster_desc': 'साथी शिल्पकारों से जुड़ें और बड़े बल्क ऑर्डर्स आसानी से पूरे करें',
      'banner_cluster_cta': 'क्लस्टर देखें',
      'banner_passport_title': 'डिजिटल शिल्प पासपोर्ट',
      'banner_passport_desc': 'हर उत्पाद को दें प्रामाणिकता प्रमाण और खरीदारों का विश्वास',
      'banner_passport_cta': 'अधिक जानें',
      'stat_products_listed': 'शिल्प उत्पाद',
      'stat_orders_to_pack': 'पैक करने योग्य',
      'stat_earnings_month': 'इस महीने',
      'stat_active': 'सक्रिय',
      'stat_pending': 'प्रतीक्षारत',
      'quick_actions_title': 'त्वरित कार्य',
      'quick_actions': 'त्वरित कार्य',
      'qa_add_craft_title': 'शिल्प जोड़ें',
      'qa_add_craft_sub': 'नया उत्पाद सूची में जोड़ें',
      'qa_orders_title': 'ऑर्डर्स',
      'qa_orders_sub': 'डिलीवरी व स्थिति देखें',
      'qa_analytics_title': 'बिज़नेस रिपोर्ट',
      'qa_analytics_sub': 'बिक्री व रुझान देखें',
      'qa_cluster_title': 'कारीगर क्लस्टर',
      'qa_cluster_sub': 'सामूहिक साझेदारी हब',
      'ai_guide_title': 'AI व्यापार सलाहकार',
      'ai_guide_desc': 'मूल्य निर्धारण, बाज़ार के रुझान और बिक्री बढ़ाने पर व्यक्तिगत सलाह प्राप्त करें।',
      'ai_guide_btn': 'AI से पूछें',
      'recent_orders_title': 'हालिया ऑर्डर्स',
      'top_products_title': 'सर्वश्रेष्ठ उत्पाद',
      'no_recent_orders': 'अभी कोई नया ऑर्डर नहीं मिला है',
      'no_top_products': 'अभी कोई उत्पाद बिक्री डेटा नहीं है',
      'status_delivered': 'वितरित',
      'status_pending': 'पैक करना बाकी',
      'status_shipped': 'भेजा गया',
      'status_ready_to_pack': 'पैक करने हेतु तैयार',
      'time_today': 'आज',
      'time_yesterday': 'कल',
      'sales_count': 'बिक्री',
      'best_seller_badge': 'बेस्ट सेलर 🌟',
      'stock_available': 'उपलब्ध',

      // Catalog Screen
      'catalog_title': 'शिल्प सूची',
      'catalog_smart_scan_title': 'स्मार्ट AI कैमरा स्कैन',
      'catalog_smart_scan_desc': 'फोटो खींचें, AI विवरण व उचित मूल्य सुझाव अपने आप बनाएगा',
      'catalog_smart_scan_btn': 'AI कैमरा खोलें',
      'catalog_header': 'हस्तशिल्प उत्पाद सूची',
      'catalog_count_suffix': 'उत्पाद सूचीबद्ध',
      'my_products_title': 'मेरे उत्पाद',
      'no_products': 'अभी कोई उत्पाद सूचीबद्ध नहीं है',
      'add_first_product': 'पहला उत्पाद जोड़ें',

      // Orders Screen
      'orders_title': 'ऑर्डर्स',
      'order_filter_all': 'सभी',
      'order_filter_pending': '⏳ प्रतीक्षारत',
      'order_filter_confirmed': '✅ पुष्ट',
      'order_filter_shipped': '🚚 भेजा गया',
      'order_filter_delivered': '📦 वितरित',
      'order_filter_paid': '💰 भुगतान प्राप्त',
      'order_total_amount': 'कुल राशि',
      'order_buyer_label': 'खरीदार',
      'order_qty_label': 'मात्रा',
      'order_no_orders': 'कोई ऑर्डर नहीं मिला',
      'order_pending_banner': 'आपके {count} ऑर्डर मंजूरी के इंतज़ार में हैं',
      'orders_empty_desc': 'खरीदारों के नए ऑर्डर यहाँ दिखाई देंगे',
      'order_confirm_btn': 'पुष्टि करें',
      'order_ship_btn': 'भेजें',
      'order_deliver_btn': 'वितरित चिह्नित करें',

      // Add Product Screen
      'add_product_title': 'नया उत्पाद जोड़ें',
      'edit_product_title': 'उत्पाद संपादित करें',
      'product_photo_section': 'उत्पाद फोटो',
      'product_details_section': 'उत्पाद विवरण',
      'product_name_label': 'उत्पाद का नाम',
      'product_category_label': 'श्रेणी',
      'product_price_label': 'मूल्य (₹)',
      'product_stock_label': 'स्टॉक मात्रा',
      'product_desc_label': 'उत्पाद विवरण एवं कहानी',
      'upload_photo_prompt': 'फोटो अपलोड करें',
      'upload_photo_sub': 'कैमरा या गैलरी से उत्पाद की तस्वीर चुनें',
      'choose_photo_btn': 'फोटो चुनें',
      'take_photo_option': 'कैमरा से फोटो खींचें',
      'gallery_option': 'गैलरी या फ़ाइल्स से चुनें',
      'enhance_photo_btn': 'स्टूडियो AI से सुधारें',
      'studio_enhanced_ready': 'स्टूडियो क्वालिटी फोटो तैयार!',
      'choice_enhanced': 'स्टूडियो AI फोटो (अनुशंसित)',
      'choice_original': 'मूल फोटो',
      'submit_product_btn': 'उत्पाद प्रकाशित करें',
      'update_product_btn': 'उत्पाद अपडेट करें',
      'product_published_msg': 'उत्पाद सफलतापूर्वक बाज़ार में जुड़ गया!',
      'product_updated_msg': 'उत्पाद सफलतापूर्वक अपडेट हो गया!',
      'take_photo_btn': 'फोटो खींचें / स्टूडियो सुधार',
      'record_voice_btn': 'बोलकर विवरण दर्ज करें',

      // Profile Screen
      'profile_title': 'प्रोफ़ाइल एवं भाषा',
      'app_language_heading': 'ऐप की भाषा',
      'language_chosen_prefix': 'भाषा',
      'bank_account_title': 'बैंक खाता और भुगतान',
      'bank_account_sub': 'खाता विवरण व भुगतान सेटिंग्स',
      'artisan_story_title': 'शिल्पकार की कहानी',
      'artisan_story_sub': 'अपनी कला की ऑडियो कहानी रिकॉर्ड करें',
      'helpline_title': 'शिल्पकार हेल्पलाइन',
      'helpline_sub': 'कॉल करें: 1800-120-SHILP (मुफ्त सहायता)',
      'sign_out_btn': 'लॉग आउट',
      'login_switch_btn': 'लॉग इन / खाता बदलें',
      'logged_out_msg': 'सफलतापूर्वक लॉग आउट हो गए',
      'account_type': 'खाता प्रकार',
      'contact_info': 'संपर्क विवरण',
      'role_artisan_label': 'शिल्पकार',
      'role_buyer_label': 'खरीदार',

      // Voice Catalog & AI Assistant
      'voice_assistant_title': 'AI व्यापार सहायक',
      'voice_assistant_sub': 'बोलकर व्यापार सहायक से बात करें',
      'voice_assistant_btn': 'बोलकर व्यापार सहायक से बात करें',
      'voice_catalog_title': 'बोलकर उत्पाद जोड़ें',
      'business_counselor': 'AI व्यापार सलाहकार',
      'virtual_clusters': 'वर्चुअल क्लस्टर समूह',
      'view_analytics': 'बिजनेस एनालिटिक्स',
      'recent_products': 'आपके हालिया उत्पाद',
      'add_new_product': 'नया उत्पाद जोड़ें',

      // Profile Completion Flow
      'profile_completion_title': 'कारीगर प्रोफ़ाइल विवरण',
      'profile_completion_sub': 'अपनी व्यक्तिगत जानकारी, अनुभव और शिल्प कहानी साझा करें',
      'step_basic_info': 'बुनियादी जानकारी',
      'step_personal_info': 'व्यक्तिगत व अनुभव',
      'step_photos': 'प्रोफ़ाइल फोटो',
      'step_story': 'शिल्पकार की कहानी',
      'voice_fill_banner_title': 'बोलकर पूरी प्रोफ़ाइल भरें',
      'voice_fill_banner_sub': 'अपने बारे में बोलें, AI सभी फ़ील्ड अपने आप भर देगा',
      'voice_fill_btn': 'माइक दबाकर बोलें',
      'voice_listening': 'सुन रहे हैं... बोलिए',
      'voice_processing': 'विवरण निकाला जा रहा है...',
      'dob_label': 'जन्म तिथि / जन्म वर्ष',
      'gender_label': 'लिंग',
      'gender_male': 'पुरुष',
      'gender_female': 'महिला',
      'gender_other': 'अन्य',
      'marital_status_label': 'वैवाहिक स्थिति',
      'status_married': 'विवाहित',
      'status_single': 'अविवाहित',
      'experience_years_label': 'शिल्पकला का अनुभव (वर्षों में)',
      'profile_photo_label': 'प्रोफ़ाइल फोटो (अवतार)',
      'cover_photo_label': 'कवर फोटो (बैनर)',
      'change_photo_btn': 'फोटो बदलें',
      'story_field_label': 'आपकी शिल्प यात्रा एवं कहानी',
      'story_field_hint': 'आप कितने समय से यह शिल्प बना रहे हैं, यह कला किसने सिखाई, और आपके काम में क्या खास है...',
      'read_more': 'पूरा पढ़ें',
      'show_less': 'कम देखें',
      'save_profile_btn': 'प्रोफ़ाइल सहेजें एवं आगे बढ़ें',
      'next_btn': 'आगे बढ़ें',
      'back_btn': 'पीछे जाएं',
      'skip_for_now': 'अभी छोड़ें (बाद में भरें)',
      'profile_saved_success': 'आपकी प्रोफ़ाइल सफलतापूर्वक सहेजी गई!',
    },

    // ═════════════════════════════════════════════════════════════════════════
    // ENGLISH (en)
    // ═════════════════════════════════════════════════════════════════════════
    'en': {
      // App Branding & General
      'app_title': 'ShilpSetu',
      'app_tagline': 'Tradition • Craft • Tomorrow',
      'app_subtitle': 'Connecting artisans to the world',
      'see_all': 'See All',
      'price_currency': '₹',
      'continue': 'Continue',

      // Language Selection
      'choose_language': 'Choose Your Language',
      'choose_language_sub': 'Select your preferred language to continue',

      // Authentication (Signup & Login)
      'signup_title': 'Create Account',
      'step_1_sub': 'Step 1 of 2 — Enter your details',
      'step_2_sub': 'Step 2 of 2 — Choose your role',
      'full_name': 'Full Name',
      'email': 'Email Address',
      'password': 'Password',
      'phone': 'Phone Number',
      'next_role': 'Next: Choose Role',
      'already_have_account': 'Already have an account? Log In',
      'login_title': 'Welcome to ShilpSetu',
      'login_sub': 'Connecting artisans to the world',
      'forgot_password': 'Forgot Password?',
      'login_btn': 'Log In',
      'create_account_btn': 'Create New Account',
      'create_my_account_btn': 'Create My Account',
      'role_change_note': 'You can always change your role later in Profile settings.',
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
      'role_sub': 'What would you like to do on ShilpSetu?',
      'role_artisan': 'I am an Artisan',
      'role_artisan_desc': 'List your crafts, receive direct orders, and grow your business',
      'role_buyer': 'I am a Buyer',
      'role_buyer_desc': 'Source authentic crafts directly from verified artisans',

      // Navigation Tabs & Screen Titles
      'tab_home': 'Home',
      'tab_products': 'Catalog',
      'tab_orders': 'Orders',
      'tab_profile': 'Profile',
      'tab_discover': 'Discover',
      'tab_rfq': 'RFQ',
      'buyer_rfq_title': 'Request Quote (RFQ)',
      'title_home': 'ShilpSetu • Home',
      'title_catalog': 'Craft Catalog',
      'title_orders': 'Orders & Delivery',
      'title_profile': 'Artisan Profile',

      // Artisan Home Screen
      'greeting_artisan': 'Hello, Artisan!',
      'greeting_buyer': 'Welcome, Buyer!',
      'home_greeting_prefix': 'Namaste',
      'home_overview_subtitle': 'Your daily craft business overview',
      'banner_sell_title': 'Sell Your Craft',
      'banner_sell_desc': 'Connect directly with buyers across India & get fair value for your work',
      'banner_sell_cta': 'Get Started',
      'banner_cluster_title': 'Artisan Clusters',
      'banner_cluster_desc': 'Collaborate with fellow craftspeople to fulfill high-volume orders',
      'banner_cluster_cta': 'View Clusters',
      'banner_passport_title': 'Digital Craft Passport',
      'banner_passport_desc': 'Provide tamper-proof authenticity and origin verification for buyers',
      'banner_passport_cta': 'Learn More',
      'stat_products_listed': 'Products Listed',
      'stat_orders_to_pack': 'Orders to Pack',
      'stat_earnings_month': 'This Month',
      'stat_active': 'Active',
      'stat_pending': 'Pending',
      'quick_actions_title': 'Quick Actions',
      'quick_actions': 'Quick Actions',
      'qa_add_craft_title': 'Add Craft',
      'qa_add_craft_sub': 'List a new craft product',
      'qa_orders_title': 'Orders',
      'qa_orders_sub': 'Track shipments & status',
      'qa_analytics_title': 'Analytics',
      'qa_analytics_sub': 'View sales & earnings report',
      'qa_cluster_title': 'Craft Hub',
      'qa_cluster_sub': 'Virtual artisan cluster',
      'ai_guide_title': 'AI Business Guide',
      'ai_guide_desc': 'Get personalized advice on fair pricing, market demand & seasonal trends.',
      'ai_guide_btn': 'Ask AI',
      'recent_orders_title': 'Recent Orders',
      'top_products_title': 'Top Products',
      'no_recent_orders': 'No orders received yet',
      'no_top_products': 'No product sales data yet',
      'status_delivered': 'Delivered',
      'status_pending': 'Pending Pack',
      'status_shipped': 'Shipped',
      'status_ready_to_pack': 'Ready to Pack',
      'time_today': 'Today',
      'time_yesterday': 'Yesterday',
      'sales_count': 'sales',
      'best_seller_badge': 'Best Seller 🌟',
      'stock_available': 'available',

      // Catalog Screen
      'catalog_title': 'Craft Catalog',
      'catalog_smart_scan_title': 'Smart AI Camera Scan',
      'catalog_smart_scan_desc': 'Snap a photo, AI generates description & fair pricing automatically',
      'catalog_smart_scan_btn': 'Open AI Camera',
      'catalog_header': 'Handicraft Catalog',
      'catalog_count_suffix': 'products listed',
      'my_products_title': 'My Products',
      'no_products': 'No products listed yet',
      'add_first_product': 'Add Your First Product',

      // Orders Screen
      'orders_title': 'Orders',
      'order_filter_all': 'All',
      'order_filter_pending': '⏳ Pending',
      'order_filter_confirmed': '✅ Confirmed',
      'order_filter_shipped': '🚚 Shipped',
      'order_filter_delivered': '📦 Delivered',
      'order_filter_paid': '💰 Paid',
      'order_total_amount': 'Total Amount',
      'order_buyer_label': 'Buyer',
      'order_qty_label': 'Qty',
      'order_no_orders': 'No orders found',
      'order_pending_banner': 'You have {count} pending order(s) to confirm',
      'orders_empty_desc': 'Orders from buyers will appear here',
      'order_confirm_btn': 'Confirm',
      'order_ship_btn': 'Mark In-Transit',
      'order_deliver_btn': 'Mark Delivered',

      // Add Product Screen
      'add_product_title': 'Add New Product',
      'edit_product_title': 'Edit Product',
      'product_photo_section': 'Product Photo',
      'product_details_section': 'Product Details',
      'product_name_label': 'Product Title',
      'product_category_label': 'Category',
      'product_price_label': 'Price (₹)',
      'product_stock_label': 'Stock Quantity',
      'product_desc_label': 'Product Story & Craft Method',
      'upload_photo_prompt': 'Upload Photo',
      'upload_photo_sub': 'Choose craft photo from Camera or Gallery',
      'choose_photo_btn': 'Choose Photo',
      'take_photo_option': 'Take Photo with Camera',
      'gallery_option': 'Choose from Gallery / Files',
      'enhance_photo_btn': 'Enhance Photo (Studio AI)',
      'studio_enhanced_ready': 'Studio Quality Photo Ready!',
      'choice_enhanced': 'Studio AI Photo (Recommended)',
      'choice_original': 'Original Photo',
      'submit_product_btn': 'Publish Product Listing',
      'update_product_btn': 'Update Product Listing',
      'product_published_msg': 'Product published successfully to marketplace!',
      'product_updated_msg': 'Product updated successfully!',
      'take_photo_btn': 'Capture Photo / Studio Polish',
      'record_voice_btn': 'Record Story via Voice Input',

      // Profile Screen
      'profile_title': 'Profile & Preferences',
      'app_language_heading': 'App Language',
      'language_chosen_prefix': 'Language',
      'bank_account_title': 'Bank Account & Payouts',
      'bank_account_sub': 'Account details and payout settings',
      'artisan_story_title': 'Artisan Story',
      'artisan_story_sub': 'Record a 1-minute audio story of your craft',
      'helpline_title': 'Artisan Helpline',
      'helpline_sub': 'Toll-Free: 1800-120-SHILP (Free Support)',
      'sign_out_btn': 'Log Out',
      'login_switch_btn': 'Log In / Switch Account',
      'logged_out_msg': 'Logged out successfully',
      'account_type': 'Account Type',
      'contact_info': 'Contact Info',
      'role_artisan_label': 'Artisan',
      'role_buyer_label': 'Buyer',

      // Voice Catalog & AI Assistant
      'voice_assistant_title': 'AI Business Assistant',
      'voice_assistant_sub': 'Speak with AI Business Assistant',
      'voice_assistant_btn': 'Speak with AI Business Assistant',
      'voice_catalog_title': 'Add Product via Voice',
      'business_counselor': 'AI Business Counselor',
      'virtual_clusters': 'Virtual Clusters',
      'view_analytics': 'Business Analytics',
      'recent_products': 'Your Recent Products',
      'add_new_product': 'Add New Product',

      // Profile Completion Flow
      'profile_completion_title': 'Artisan Profile Details',
      'profile_completion_sub': 'Share your personal information, experience, and craft journey',
      'step_basic_info': 'Basic Info',
      'step_personal_info': 'Personal & Craft',
      'step_photos': 'Photos',
      'step_story': 'Artisan Story',
      'voice_fill_banner_title': 'Fill Profile by Voice',
      'voice_fill_banner_sub': 'Speak naturally about yourself, AI will auto-fill all fields',
      'voice_fill_btn': 'Tap Mic to Speak',
      'voice_listening': 'Listening... Please speak',
      'voice_processing': 'Extracting profile details...',
      'dob_label': 'Date of Birth / Birth Year',
      'gender_label': 'Gender',
      'gender_male': 'Male',
      'gender_female': 'Female',
      'gender_other': 'Other',
      'marital_status_label': 'Marital Status',
      'status_married': 'Married',
      'status_single': 'Single',
      'experience_years_label': 'Years of Craft Experience',
      'profile_photo_label': 'Profile Photo (Avatar)',
      'cover_photo_label': 'Cover Photo (Banner)',
      'change_photo_btn': 'Change Photo',
      'story_field_label': 'Your Craft Journey & Story',
      'story_field_hint': 'Describe how you learned your craft, your family lineage, and what makes your handmade work unique...',
      'read_more': 'Read More',
      'show_less': 'Show Less',
      'save_profile_btn': 'Save Profile & Continue',
      'next_btn': 'Next',
      'back_btn': 'Back',
      'skip_for_now': 'Skip for Now',
      'profile_saved_success': 'Your profile was saved successfully!',
    },

    // ═════════════════════════════════════════════════════════════════════════
    // MARATHI (mr)
    // ═════════════════════════════════════════════════════════════════════════
    'mr': {
      // App Branding & General
      'app_title': 'शिल्पसेतू',
      'app_tagline': 'परंपरा • शिल्प • भविष्य',
      'app_subtitle': 'कारागिरांना जगाशी जोडणे',
      'see_all': 'सर्व पहा',
      'price_currency': '₹',
      'continue': 'पुढे जा',

      // Language Selection
      'choose_language': 'तुमची भाषा निवडा',
      'choose_language_sub': 'पुढे जाण्यासाठी तुमची आवडती भाषा निवडा',

      // Authentication (Signup & Login)
      'signup_title': 'खाते तयार करा',
      'step_1_sub': 'टप्पा 1/2 — तुमचा तपशील भरा',
      'step_2_sub': 'टप्पा 2/2 — तुमची भूमिका निवडा',
      'full_name': 'पूर्ण नाव',
      'email': 'ईमेल पत्ता',
      'password': 'पासवर्ड',
      'phone': 'फोन नंबर',
      'next_role': 'पुढील: भूमिका निवडा',
      'already_have_account': 'आधीच खाते आहे? लॉग इन करा',
      'login_title': 'शिल्पसेतूमध्ये आपले स्वागत आहे',
      'login_sub': 'कारागिरांना जगाशी जोडणे',
      'forgot_password': 'पासवर्ड विसरलात?',
      'login_btn': 'लॉग इन करा',
      'create_account_btn': 'नवीन खाते तयार करा',
      'create_my_account_btn': 'माझे खाते तयार करा',
      'role_change_note': 'तुम्ही नंतर प्रोफाइल सेटिंग्जमध्ये तुमची भूमिका बदलू शकता.',
      'email_login': 'ईमेल लॉगिन',
      'phone_login': 'फोन नंबर लॉगिन',
      'send_otp': 'OTP पाठवा',
      'enter_otp': '6-अंकी OTP टाका',
      'verify_otp': 'सत्यापित करा आणि लॉगिन करा',
      'reset_title': 'पासवर्ड रीसेट करा',
      'reset_sub': 'तुमचा नोंदणीकृत ईमेल प्रविष्ट करा',
      'send_reset_link': 'रीसेट लिंक पाठवा',
      'reset_sent_msg': 'ईमेलवर रीसेट लिंक पाठवली आहे!',

      // Role Selection
      'role_title': 'तुमची भूमिका कोणती आहे?',
      'role_sub': 'तुम्ही शिल्पसेतूवर काय करू इच्छिता?',
      'role_artisan': 'मी एक कारागीर आहे',
      'role_artisan_desc': 'तुमच्या हस्तकलांची यादी तयार करा, थेट ऑर्डर्स मिळवा आणि विक्री वाढवा',
      'role_buyer': 'मी एक खरेदीदार आहे',
      'role_buyer_desc': 'प्रमाणित कारागिरांकडून थेट हस्तकला खरेदी करा आणि मोठ्या ऑर्डर्स द्या',

      // Navigation Tabs & Screen Titles
      'tab_home': 'मुख्य',
      'tab_products': 'शिल्प सूची',
      'tab_orders': 'ऑर्डर्स',
      'tab_profile': 'प्रोफाइल',
      'tab_discover': 'शोधा',
      'tab_rfq': 'कोटेशन',
      'buyer_rfq_title': 'दरपत्रक मागणी',
      'title_home': 'शिल्पसेतू • मुख्य',
      'title_catalog': 'शिल्प सूची',
      'title_orders': 'ऑर्डर्स आणि वितरण',
      'title_profile': 'कारागीर प्रोफाइल',

      // Artisan Home Screen
      'greeting_artisan': 'नमस्कार, कारागीर जी!',
      'greeting_buyer': 'नमस्कार, स्वागत आहे!',
      'home_greeting_prefix': 'नमस्कार',
      'home_overview_subtitle': 'तुमचा दैनंदिन हस्तकला व्यवसाय सारांश',
      'banner_sell_title': 'तुमची हस्तकला विका',
      'banner_sell_desc': 'देशभरातील खरेदीदारांशी थेट जोडा आणि तुमच्या कलेचे योग्य मूल्य मिळवा',
      'banner_sell_cta': 'सुरू करा',
      'banner_cluster_title': 'कारागीर क्लस्टर',
      'banner_cluster_desc': 'सहकारी कारागिरांशी हातमिळवणी करा आणि मोठ्या ऑर्डर्स पूर्ण करा',
      'banner_cluster_cta': 'क्लस्टर पहा',
      'banner_passport_title': 'डिजिटल शिल्प पासपोर्ट',
      'banner_passport_desc': 'प्रत्येक उत्पादनाला द्या अस्सलतेचे प्रमाणपत्र आणि खरेदीदारांचा विश्वास',
      'banner_passport_cta': 'अधिक माहिती',
      'stat_products_listed': 'शिल्प उत्पादने',
      'stat_orders_to_pack': 'पॅक करायच्या ऑर्डर्स',
      'stat_earnings_month': 'या महिन्यात',
      'stat_active': 'सक्रिय',
      'stat_pending': 'प्रलंबित',
      'quick_actions_title': 'जलद कृती',
      'quick_actions': 'जलद कृती',
      'qa_add_craft_title': 'शिल्प जोडा',
      'qa_add_craft_sub': 'नवीन उत्पादन यादीत जोडा',
      'qa_orders_title': 'ऑर्डर्स',
      'qa_orders_sub': 'वितरण आणि स्थिती पहा',
      'qa_analytics_title': 'व्यवसाय अहवाल',
      'qa_analytics_sub': 'विक्री आणि कल पहा',
      'qa_cluster_title': 'कारागीर हब',
      'qa_cluster_sub': 'सामूहिक भागीदारी गट',
      'ai_guide_title': 'AI व्यवसाय मार्गदर्शक',
      'ai_guide_desc': 'योग्य किंमत, बाजारातील मागणी आणि विक्री वाढीवर वैयक्तिक सल्ला मिळवा.',
      'ai_guide_btn': 'AI ला विचारा',
      'recent_orders_title': 'अलीकडील ऑर्डर्स',
      'top_products_title': 'सर्वोत्कृष्ट उत्पादने',
      'no_recent_orders': 'अद्याप कोणतीही ऑर्डर मिळालेली नाही',
      'no_top_products': 'अद्याप विक्री डेटा उपलब्ध नाही',
      'status_delivered': 'वितरित',
      'status_pending': 'पॅक करणे बाकी',
      'status_shipped': 'पाठवले',
      'status_ready_to_pack': 'पॅक करण्यासाठी सज्ज',
      'time_today': 'आज',
      'time_yesterday': 'काल',
      'sales_count': 'विक्री',
      'best_seller_badge': 'बेस्ट सेलर 🌟',
      'stock_available': 'उपलब्ध',

      // Catalog Screen
      'catalog_title': 'शिल्प सूची',
      'catalog_smart_scan_title': 'स्मार्ट AI कॅमेरा स्कॅन',
      'catalog_smart_scan_desc': 'फोटो काढा, AI आपोआप वर्णन आणि योग्य किंमत सुचवेल',
      'catalog_smart_scan_btn': 'AI कॅमेरा उघडा',
      'catalog_header': 'हस्तकला उत्पादनांची यादी',
      'catalog_count_suffix': 'उत्पादने सूचीबद्ध',
      'my_products_title': 'माझी उत्पादने',
      'no_products': 'अद्याप कोणतेही उत्पादन सूचीबद्ध नाही',
      'add_first_product': 'पहिले उत्पादन जोडा',

      // Orders Screen
      'orders_title': 'ऑर्डर्स',
      'order_filter_all': 'सर्व',
      'order_filter_pending': '⏳ प्रलंबित',
      'order_filter_confirmed': '✅ पुष्टी झाली',
      'order_filter_shipped': '🚚 पाठवले',
      'order_filter_delivered': '📦 वितरित',
      'order_filter_paid': '💰 देय मिळाले',
      'order_total_amount': 'एकूण रक्कम',
      'order_buyer_label': 'खरेदीदार',
      'order_qty_label': 'प्रमाण',
      'order_no_orders': 'कोणतीही ऑर्डर आढळली नाही',
      'order_pending_banner': 'तुमच्याकडे मंजुरीसाठी {count} प्रलंबित ऑर्डर्स आहेत',
      'orders_empty_desc': 'खरेदीदारांकडून येणाऱ्या नवीन ऑर्डर्स येथे दिसतील',
      'order_confirm_btn': 'पुष्टी करा',
      'order_ship_btn': 'पाठवा',
      'order_deliver_btn': 'वितरित झाले म्हणून चिन्हांकित करा',

      // Add Product Screen
      'add_product_title': 'नवीन उत्पादन जोडा',
      'edit_product_title': 'उत्पादन संपादित करा',
      'product_photo_section': 'उत्पादन फोटो',
      'product_details_section': 'उत्पादन तपशील',
      'product_name_label': 'उत्पादनाचे नाव',
      'product_category_label': 'वर्ग / श्रेणी',
      'product_price_label': 'किंमत (₹)',
      'product_stock_label': 'शिल्लक साठा',
      'product_desc_label': 'उत्पादनाचे वर्णन आणि हस्तकला कथा',
      'upload_photo_prompt': 'फोटो अपलोड करा',
      'upload_photo_sub': 'कॅमेरा किंवा गॅलरीमधून उत्पादनाचा फोटो निवडा',
      'choose_photo_btn': 'फोटो निवडा',
      'take_photo_option': 'कॅमेऱ्याने फोटो काढा',
      'gallery_option': 'गॅलरी किंवा फाइल्समधून निवडा',
      'enhance_photo_btn': 'स्टुडिओ AI ने सुधारा',
      'studio_enhanced_ready': 'स्टुडिओ दर्जाचा फोटो तयार!',
      'choice_enhanced': 'स्टुडिओ AI फोटो (शिफारस केलेले)',
      'choice_original': 'मूळ फोटो',
      'submit_product_btn': 'उत्पादन प्रकाशित करा',
      'update_product_btn': 'उत्पादन अद्ययावत करा',
      'product_published_msg': 'उत्पादन यशस्वीरीत्या बाजारपेठेत जोडले गेले!',
      'product_updated_msg': 'उत्पादन यशस्वीरीत्या अद्ययावत झाले!',
      'take_photo_btn': 'फोटो काढा / स्टुडिओ सुधार',
      'record_voice_btn': 'बोलून माहिती नोंदवा',

      // Profile Screen
      'profile_title': 'प्रोफाइल आणि भाषा',
      'app_language_heading': 'अॅप भाषा',
      'language_chosen_prefix': 'भाषा',
      'bank_account_title': 'बँक खाते आणि पेआउट्स',
      'bank_account_sub': 'खाते तपशील आणि देयक सेटिंग्ज',
      'artisan_story_title': 'कारागिराची गोष्ट',
      'artisan_story_sub': 'तुमच्या कलेची 1 मिनिटाची ऑडिओ कथा रेकॉर्ड करा',
      'helpline_title': 'कारागीर हेल्पलाइन',
      'helpline_sub': 'कॉल करा: 1800-120-SHILP (मोफत मदत)',
      'sign_out_btn': 'लॉग आउट',
      'login_switch_btn': 'लॉग इन करा / खाते बदला',
      'logged_out_msg': 'यशस्वीरीत्या लॉग आउट केले',
      'account_type': 'खाते प्रकार',
      'contact_info': 'संपर्क तपशील',
      'role_artisan_label': 'कारागीर',
      'role_buyer_label': 'खरेदीदार',

      // Voice Catalog & AI Assistant
      'voice_assistant_title': 'AI व्यवसाय सहाय्यक',
      'voice_assistant_sub': 'बोलून व्यवसाय सहाय्यकाशी संवाद साधा',
      'voice_assistant_btn': 'बोलून व्यवसाय सहाय्यकाशी संवाद साधा',
      'voice_catalog_title': 'आवाजाद्वारे उत्पादन जोडा',
      'business_counselor': 'AI व्यवसाय सल्लागार',
      'virtual_clusters': 'व्हर्च्युअल क्लस्टर गट',
      'view_analytics': 'व्यवसाय विश्लेषण',
      'recent_products': 'तुमची अलीकडील उत्पादने',
      'add_new_product': 'नवीन उत्पादन जोडा',

      // Profile Completion Flow
      'profile_completion_title': 'कारागीर प्रोफाइल तपशील',
      'profile_completion_sub': 'तुमची वैयक्तिक माहिती, अनुभव आणि हस्तकला कथा सामायिक करा',
      'step_basic_info': 'मूलभूत माहिती',
      'step_personal_info': 'वैयक्तिक व अनुभव',
      'step_photos': 'फोटो',
      'step_story': 'कारागिराची गोष्ट',
      'voice_fill_banner_title': 'बोलून पूर्ण प्रोफाइल भरा',
      'voice_fill_banner_sub': 'तुमच्याबद्दल बोला, AI सर्व माहिती आपोआप भरेल',
      'voice_fill_btn': 'माईक दाबून बोला',
      'voice_listening': 'ऐकत आहोत... कृपया बोला',
      'voice_processing': 'माहिती काढली जात आहे...',
      'dob_label': 'जन्म तारीख / जन्माचे वर्ष',
      'gender_label': 'लिंग',
      'gender_male': 'पुरुष',
      'gender_female': 'स्त्री',
      'gender_other': 'इतर',
      'marital_status_label': 'वैवाहिक स्थिती',
      'status_married': 'विवाहित',
      'status_single': 'अविवाहित',
      'experience_years_label': 'हस्तकलेचा अनुभव (वर्षांमध्ये)',
      'profile_photo_label': 'प्रोफाइल फोटो (अवतार)',
      'cover_photo_label': 'कव्हर फोटो (बॅनर)',
      'change_photo_btn': 'फोटो बदला',
      'story_field_label': 'तुमचा हस्तकला प्रवास आणि कथा',
      'story_field_hint': 'तुम्ही ही कला कशी शिकलात, तुमच्या पूर्वजांची परंपरा आणि तुमच्या उत्पादनांचे खास वैशिष्ट्य काय आहे...',
      'read_more': 'पूर्ण वाचा',
      'show_less': 'कमी करा',
      'save_profile_btn': 'प्रोफाइल जतन करा आणि पुढे जा',
      'next_btn': 'पुढे जा',
      'back_btn': 'मागे या',
      'skip_for_now': 'आत्ता वगळा (नंतर भरा)',
      'profile_saved_success': 'तुमची प्रोफाइल यशस्वीरीत्या जतन झाली!',
    },
  };
}
