import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import '../../services/ai_catalog_service.dart';
import '../../services/recording_file.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import 'listing_review_screen.dart';

class VoiceCatalogScreen extends StatefulWidget {
  final String imageUrl;

  const VoiceCatalogScreen({
    super.key,
    required this.imageUrl,
  });

  @override
  State<VoiceCatalogScreen> createState() => _VoiceCatalogScreenState();
}

class _VoiceCatalogScreenState extends State<VoiceCatalogScreen>
    with SingleTickerProviderStateMixin {
  final AiCatalogService _aiService = AiCatalogService();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _isRecording = false;
  bool _isProcessing = false;
  int _recordSeconds = 0;
  Timer? _timer;

  String _selectedLanguage = 'hi';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      debugPrint('[VoiceCatalog] Checking and requesting microphone permissions...');
      final hasPermission = await _audioRecorder.hasPermission();
      debugPrint('[VoiceCatalog] Microphone permission granted: $hasPermission');

      if (!hasPermission) {
        _showError('माइक्रोफ़ोन की अनुमति आवश्यक है (Microphone permission was denied)');
        return;
      }

      final recordingPath = await createRecordingPath();

      // Configure recording: 16kHz mono WAV format (ideal for SpeechRecognition)
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: recordingPath,
      );

      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
      debugPrint('[VoiceCatalog] Recording successfully started!');
    } catch (e, stack) {
      debugPrint('[VoiceCatalog] Error starting recording: $e\n$stack');
      _showError('माइक्रोफ़ोन शुरू करने में त्रुटि आई: $e');
    }
  }

  Future<void> _stopAndProcessRecording({String? sampleTranscript}) async {
    _timer?.cancel();

    Uint8List? audioBytes;
    String? audioBlobPath;

    if (sampleTranscript == null && _isRecording) {
      try {
        debugPrint('[VoiceCatalog] Stopping AudioRecorder...');
        audioBlobPath = await _audioRecorder.stop();
        debugPrint('[VoiceCatalog] AudioRecorder stopped. Blob/Path: $audioBlobPath');

        if (audioBlobPath != null && audioBlobPath.isNotEmpty) {
          if (kIsWeb) {
            debugPrint('[VoiceCatalog] Fetching audio bytes from Blob URL: $audioBlobPath');
            final blobResponse = await http.get(Uri.parse(audioBlobPath));
            if (blobResponse.statusCode == 200) {
              audioBytes = blobResponse.bodyBytes;
              debugPrint('[VoiceCatalog] Received ${audioBytes.length} bytes from Blob URL');
            } else {
              debugPrint('[VoiceCatalog] Failed to read audio blob URL: ${blobResponse.statusCode}');
            }
          } else {
            debugPrint('[VoiceCatalog] Reading recorded audio file: $audioBlobPath');
            audioBytes = await readRecordedAudio(audioBlobPath);
            if (audioBytes != null) {
              debugPrint('[VoiceCatalog] Read ${audioBytes.length} bytes from recorded file');
            } else {
              debugPrint('[VoiceCatalog] Recorded audio file was missing or empty');
            }
          }
        }
      } catch (e, stack) {
        debugPrint('[VoiceCatalog] Error stopping audio recorder: $e\n$stack');
      }
    }

    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    try {
      Map<String, dynamic> result;

      if (sampleTranscript != null) {
        debugPrint('[VoiceCatalog] Using One-Tap test sample transcript...');
        result = await _aiService.voiceToListing(
          directTranscript: sampleTranscript,
          language: _selectedLanguage,
        );
      } else if (audioBytes != null && audioBytes.isNotEmpty) {
        debugPrint('[VoiceCatalog] Sending real audio (${audioBytes.length} bytes) to /api/catalog/voice-to-listing...');
        result = await _aiService.voiceToListing(
          audioBytes: audioBytes,
          audioFilename: 'artisan_recording.wav',
          language: _selectedLanguage,
        );
      } else {
        debugPrint('[VoiceCatalog] No audio bytes received; aborting process.');
        if (mounted) {
          setState(() => _isProcessing = false);
          _showError('कोई आवाज़ रिकॉर्ड नहीं हुई, कृपया दोबारा प्रयास करें');
        }
        return;
      }

      if (mounted) {
        setState(() => _isProcessing = false);

        if (result['success'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ListingReviewScreen(
                imageUrl: widget.imageUrl,
                initialTitleEn: result['title_en'] ?? 'Handcrafted Craft Item',
                initialTitleHi: result['title_hi'] ?? 'हस्तनिर्मित शिल्प उत्पाद',
                initialDescEn: result['description_en'] ?? '',
                initialDescHi: result['description_hi'] ?? '',
                initialCategory: result['category'] ?? 'Pottery',
                keyFeatures: List<String>.from(result['key_features'] ?? []),
                transcript: result['transcript'] ?? (sampleTranscript ?? ''),
              ),
            ),
          );
        } else {
          final err = result['friendly_error'] ?? result['error'] ?? 'विवरण तैयार नहीं हो सका';
          _showError(err);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showError('तकनीकी समस्या आई, कृपया दोबारा प्रयास करें');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimer(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text('🎙️ बोलकर विवरण जोड़ें (Voice Listing)'),
        backgroundColor: AppTheme.primaryTerracotta,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Product Preview Pill
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        widget.imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 60,
                          height: 60,
                          color: AppTheme.borderGrey,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            '✅ फोटो संवारी गई (1:1 Clean Studio)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'अब अपने शिल्प के बारे में बोलकर बताएं',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.darkIndigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Language Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppTheme.borderGrey),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate_rounded, size: 18, color: AppTheme.primaryTerracotta),
                    const SizedBox(width: 8),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLanguage,
                        items: const [
                          DropdownMenuItem(value: 'hi', child: Text('🇮🇳 हिंदी (Hindi)')),
                          DropdownMenuItem(value: 'en', child: Text('🌐 English')),
                          DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                          DropdownMenuItem(value: 'ta', child: Text('தமிழ் (Tamil)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLanguage = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Recording State Card
              if (_isProcessing) ...[
                // Processing Animation
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryTerracotta.withValues(alpha: 0.1),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      SizedBox(
                        height: 56,
                        width: 56,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryTerracotta,
                          strokeWidth: 4,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        '✨ AI विवरण तैयार कर रहा है...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.darkIndigo,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'हिंदी और अंग्रेजी दोनों में सूची बनाई जा रही है\n(Extracting listing & translating to English & Hindi)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Big Accessible Microphone Button
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopAndProcessRecording();
                    } else {
                      _startRecording();
                    }
                  },
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRecording ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? Colors.redAccent
                                : AppTheme.primaryTerracotta,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording
                                        ? Colors.redAccent
                                        : AppTheme.primaryTerracotta)
                                    .withValues(alpha: 0.4),
                                blurRadius: _isRecording ? 30 : 16,
                                spreadRadius: _isRecording ? 8 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Timer or Prompt
                if (_isRecording) ...[
                  Text(
                    _formatTimer(_recordSeconds),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.redAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Animated Waveform Indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (i) {
                      final heights = [14.0, 24.0, 36.0, 48.0, 32.0, 22.0, 12.0];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 5,
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: AppTheme.primaryTerracotta,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'रोकने के लिए दोबारा दबाएं (Tap again to stop)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'माइक दबाकर बोलना शुरू करें',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkIndigo,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'जैसे: "यह शुद्ध लाल मिट्टी से बना टेराकोटा कुल्हड़ है, चाय के लिए बढ़िया"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],

                const SizedBox(height: 40),

                // Quick Demo Pill: Sample Artisan Voice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '💡 त्वरित परीक्षण (One-Tap Test):',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryOchre,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkIndigo,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.record_voice_over_rounded, size: 20),
                        label: const Text(
                          'नमूना कारीगर आवाज़ से विवरण बनाएं',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: () => _stopAndProcessRecording(
                          sampleTranscript:
                              'यह शुद्ध लाल मिट्टी से बना पारंपरिक टेराकोटा कुल्हड़ और चाय सेट है, गोरखपुर के कारीगरों द्वारा चाक पर हाथ से बनाया गया',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
