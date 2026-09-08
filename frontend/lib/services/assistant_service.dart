import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AssistantService {
  final String baseUrl;

  AssistantService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Calls POST /api/assistant/ask to consult the Gemini-powered AI Business Assistant.
  Future<Map<String, dynamic>> askAssistant({
    required String artisanId,
    required String question,
    String language = 'hi',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 1200));
      return _mockAssistantAnswer(question, language);
    }

    try {
      final uri = Uri.parse('$baseUrl/api/assistant/ask');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'artisan_id': artisanId,
          'question': question,
          'language': language,
        }),
      ).timeout(const Duration(seconds: 40));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        debugPrint('Assistant API returned status ${resp.statusCode}: ${resp.body}');
        return _mockAssistantAnswer(question, language);
      }
    } catch (e) {
      debugPrint('Error calling /api/assistant/ask: $e');
      return _mockAssistantAnswer(question, language);
    }
  }

  Map<String, dynamic> _mockAssistantAnswer(String question, String language) {
    return {
      'success': true,
      'answer': language == 'hi'
          ? 'नमस्ते! आपके शिल्प की प्रामाणिकता ही आपकी सबसे बड़ी ताकत है। त्योहारों के मौसम में आकर्षक 2-इन-1 कॉम्बो पैक बनाएं और साफ़-सुथरे बैकग्राउंड वाली तस्वीरें लगाएं। उचित दाम रखने से ग्राहकों का विश्वास बढ़ता है।'
          : 'Hello! Your handcrafted heritage is unique. For festive seasons, bundle complementary products together and ensure high-contrast studio photos. A fair price builds lasting buyer trust.',
      'language': language,
      'context_summary': {
        'products_count': 2,
        'orders_count': 1,
        'categories': ['Pottery', 'Textiles']
      }
    };
  }
}
