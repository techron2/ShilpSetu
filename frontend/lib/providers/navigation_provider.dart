import 'package:flutter/material.dart';

/// Provider to manage tab navigation across the 4 primary app tabs:
/// 0: Home (गृह पृष्ठ)
/// 1: Catalog (शिल्प सूची)
/// 2: Orders (आदेश / ऑर्डर्स)
/// 3: Profile (प्रोफ़ाइल)
class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }
}
