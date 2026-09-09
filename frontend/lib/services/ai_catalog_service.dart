import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AiCatalogService {
  final String baseUrl;

  AiCatalogService({String? baseUrl}) : baseUrl = baseUrl ?? ApiConfig.baseUrl;

  /// Sends craft image bytes to the backend for background removal (rembg)
  /// and OpenCV contrast enhancement & 1080x1080 square canvas fitting.
  Future<Map<String, dynamic>> enhanceImage({
    required List<int> imageBytes,
    String filename = 'craft.jpg',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return {
        'success': true,
        'image_url': 'https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=800',
        'original_dimensions': [600, 600],
        'enhanced_dimensions': [1080, 1080],
        'is_mock': true,
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/products/enhance-image');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode == 200 && (data['success'] == true)) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Image enhancement failed',
          'friendly_error': data['friendly_error'] ?? 'फोटो संवारने में समस्या आई, कृपया दोबारा प्रयास करें',
        };
      }
    } catch (e) {
      debugPrint('Error calling /api/products/enhance-image: $e');
      // Graceful fallback for offline development
      return {
        'success': false,
        'error': e.toString(),
        'friendly_error': 'सर्वर से संपर्क नहीं हो सका (Could not reach server)',
      };
    }
  }

  /// Uploads raw/original image bytes to backend / storage without enhancement.
  Future<Map<String, dynamic>> uploadRawImage({
    required List<int> imageBytes,
    String filename = 'craft.jpg',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      return {
        'success': true,
        'image_url': 'https://images.unsplash.com/photo-1615865417491-9941019fbc00?w=800',
        'filename': filename,
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/products/upload-image');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode == 200 && (data['success'] == true)) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Image upload failed',
          'friendly_error': data['friendly_error'] ?? 'फोटो अपलोड करने में समस्या आई',
        };
      }
    } catch (e) {
      debugPrint('Error calling /api/products/upload-image: $e');
      return {
        'success': false,
        'error': e.toString(),
        'friendly_error': 'सर्वर से संपर्क नहीं हो सका (Could not reach server)',
      };
    }
  }

  /// Sends recorded audio bytes or transcript to the backend for transcription,
  /// structured extraction via Gemini AI, and bilingual translation.
  Future<Map<String, dynamic>> voiceToListing({
    List<int>? audioBytes,
    String? audioFilename,
    String? directTranscript,
    String language = 'hi',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 1500));
      return {
        'success': true,
        'transcript': 'यह शुद्ध लाल मिट्टी से बना पारंपरिक टेराकोटा कुल्हड़ और चाय सेट है',
        'title_en': 'Handcrafted Terracotta Chai Kulhad Set',
        'title_hi': 'हस्तनिर्मित टेराकोटा चाय कुल्हड़ सेट',
        'description_en': 'Pure natural terracotta clay kulhad set handcrafted on traditional potter wheel by rural artisans. 100% organic and eco-friendly.',
        'description_hi': 'पारंपरिक चाक पर शुद्ध प्राकृतिक मिट्टी से तैयार किया गया पर्यावरण-अनुकूल कुल्हड़ सेट। 100% प्राकृतिक और जैविक।',
        'category': 'Pottery',
        'key_features': [
          '100% शुद्ध प्राकृतिक चिकनी मिट्टी',
          'पारंपरिक चाक पर हस्तनिर्मित',
          'माइक्रोवेव और पर्यावरण अनुकूल',
          'ग्रामीण शिल्पकार सहायता',
        ],
        'is_mock': true,
      };
    }

    try {
      final uri = Uri.parse('$baseUrl/api/catalog/voice-to-listing');

      if (directTranscript != null && directTranscript.trim().isNotEmpty) {
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transcript': directTranscript.trim(),
            'language': language,
          }),
        ).timeout(const Duration(seconds: 40));

        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data;
      } else if (audioBytes != null && audioBytes.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.fields['language'] = language;
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audioBytes,
            filename: audioFilename ?? 'artisan_voice.wav',
          ),
        );

        final streamed = await request.send().timeout(const Duration(seconds: 45));
        final respStr = await streamed.stream.bytesToString();
        final data = jsonDecode(respStr) as Map<String, dynamic>;
        return data;
      } else {
        return {
          'success': false,
          'error': 'No audio or transcript provided',
          'friendly_error': 'कृपया पहले बोलकर विवरण दें (Please record voice first)',
        };
      }
    } catch (e) {
      debugPrint('Error calling /api/catalog/voice-to-listing: $e');
      return {
        'success': false,
        'error': e.toString(),
        'friendly_error': 'सर्वर से संपर्क नहीं हो सका (Could not connect to server)',
      };
    }
  }
}
