import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  String get baseUrl => ApiConfig.baseUrl;

  /// Calls POST /api/profile/voice-to-profile with audio bytes or transcript text.
  Future<Map<String, dynamic>> voiceToProfile({
    List<int>? audioBytes,
    String? audioFilename,
    String? directTranscript,
    String language = 'hi',
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/profile/voice-to-profile');

      if (directTranscript != null && directTranscript.trim().isNotEmpty) {
        final resp = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'transcript': directTranscript.trim(),
            'language': language,
          }),
        ).timeout(const Duration(seconds: 40));

        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else if (audioBytes != null && audioBytes.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri);
        request.fields['language'] = language;
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audioBytes,
            filename: audioFilename ?? 'profile_audio.wav',
          ),
        );

        final streamed = await request.send().timeout(const Duration(seconds: 60));
        final response = await http.Response.fromStream(streamed);
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'No audio or transcript provided',
          'friendly_error': 'कृपया पहले बोलकर विवरण दें (Please record voice first)',
        };
      }
    } catch (e) {
      debugPrint('[ProfileService] voiceToProfile error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'friendly_error': 'तकनीकी समस्या आई, कृपया पुनः प्रयास करें',
      };
    }
  }

  /// Saves updated profile to `PUT /api/users/<uid>/profile`.
  Future<Map<String, dynamic>> saveProfile(String uid, Map<String, dynamic> data) async {
    try {
      final uri = Uri.parse('$baseUrl/api/users/$uid/profile');
      final resp = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 25));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        return {
          'success': false,
          'error': 'Server error: ${resp.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('[ProfileService] saveProfile error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Uploads raw image bytes to POST /api/products/upload-image and returns public URL.
  Future<String?> uploadImage(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/api/products/upload-image');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('image', bytes, filename: filename),
      );
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['image_url'] as String?;
      }
    } catch (e) {
      debugPrint('[ProfileService] uploadImage error: $e');
    }
    return null;
  }
}
