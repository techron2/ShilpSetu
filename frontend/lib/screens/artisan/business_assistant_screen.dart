import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/assistant_service.dart';
import '../../services/recording_file.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class BusinessAssistantScreen extends StatefulWidget {
  final AssistantService? assistantService;

  const BusinessAssistantScreen({super.key, this.assistantService});

  @override
  State<BusinessAssistantScreen> createState() => _BusinessAssistantScreenState();
}

class _BusinessAssistantScreenState extends State<BusinessAssistantScreen>
    with SingleTickerProviderStateMixin {
  late final AssistantService _assistantService;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  String _selectedLang = 'hi'; // 'hi', 'mr', 'en'
  int _activeRequestId = 0; // Monotonic request counter to prevent race conditions and stale responses

  final List<String> _quickPromptsHi = [
    '🪔 दीवाली पर सही दाम क्या रखें?',
    '📈 बिक्री और ऑर्डर कैसे बढ़ाएं?',
    '📦 सुरक्षित और सुंदर पैकेजिंग कैसे करें?',
    '🏙️ बड़े शहरों के ग्राहकों को कैसे आकर्षित करें?',
    '💰 क्या मुझे कॉम्बो उपहार सेट बनाना चाहिए?'
  ];

  final List<String> _quickPromptsMr = [
    '🪔 सणांसाठी योग्य किंमत कशी ठरवावी?',
    '📈 ऑर्डर्स आणि विक्री कशी वाढवावी?',
    '📦 सुरक्षित आणि आकर्षक पॅकेजिंग कसे करावे?',
    '🏙️ मोठ्या शहरांतील ग्राहक कसे मिळवावे?',
    '💰 फेस्टिव्ह कॉम्बो गिफ्ट पॅक कसा बनवावा?'
  ];

  final List<String> _quickPromptsEn = [
    '🪔 What pricing strategy should I use for festive seasons?',
    '📈 How can I increase customer orders for my craft?',
    '📦 What are safe eco-friendly packaging best practices?',
    '🏙️ How to attract buyers in metropolitan cities?',
    '💰 Should I create handcrafted gift bundles?'
  ];

  @override
  void initState() {
    super.initState();
    _assistantService = widget.assistantService ?? AssistantService();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Sync initial language from LanguageProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final langProv = context.read<LanguageProvider>();
      final appLang = langProv.currentLanguageCode;
      setState(() {
        _selectedLang = appLang;
        _messages.clear();
        _messages.add(_buildWelcomeMessage(appLang));
      });
    });
  }

  ChatMessage _buildWelcomeMessage(String lang) {
    String text;
    if (lang == 'mr') {
      text = 'नमस्ते शिल्पकार जी! 🙏 मी आपला हुनरसाथी व्यापार सहाय्यक आहे. '
          'आपण मला आपल्या हस्तकलेची किंमत, विक्री वाढवण्याचे मार्ग, सणांचे गिफ्ट पॅक किंवा सुरक्षित पॅकेजिंगविषयी कोणताही प्रश्न विचारू शकता.';
    } else if (lang == 'en') {
      text = 'Hello Artisan! 🙏 I am your HunarSathi Business Assistant. '
          'You can consult me on pricing formulas, increasing customer orders, safe packaging, or festive gift bundles.';
    } else {
      text = 'नमस्ते शिल्पकार जी! 🙏 मैं आपका हुनरसाथी व्यापार सहायक हूँ। '
          'आप मुझसे अपने शिल्प की कीमत, बिक्री बढ़ाने के तरीके, त्योहारों के उपहार सेट या सुरक्षित पैकेजिंग के बारे में कोई भी सवाल पूछ सकते हैं।';
    }
    return ChatMessage(text: text, isUser: false, timestamp: DateTime.now());
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _textCtrl.dispose();
    _textFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isTranscribing || _isSending) return;

    if (_isRecording) {
      await _stopVoiceRecording();
    } else {
      await _startVoiceRecording();
    }
  }

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedLang == 'mr'
                  ? 'मायक्रोफोनची परवानगी नाकारली आहे. कृपया परवानगी द्या.'
                  : (_selectedLang == 'en'
                      ? 'Microphone permission denied. Please allow microphone access.'
                      : 'माइक्रोफ़ोन की अनुमति नहीं मिली। कृपया सेटिंग्स में अनुमति दें।'),
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final recordingPath = await createRecordingPath();

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
      _pulseController.repeat(reverse: true);

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) {
          setState(() {
            _recordSeconds++;
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('माइक्रोफ़ोन शुरू करने में त्रुटि: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _stopVoiceRecording() async {
    _recordTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    Uint8List? audioBytes;
    try {
      final audioPath = await _audioRecorder.stop();
      if (audioPath != null && audioPath.isNotEmpty) {
        if (kIsWeb) {
          final blobRes = await http.get(Uri.parse(audioPath));
          if (blobRes.statusCode == 200) {
            audioBytes = blobRes.bodyBytes;
          }
        } else {
          debugPrint('[BusinessAssistant] Reading recorded audio file: $audioPath');
          audioBytes = await readRecordedAudio(audioPath);
          if (audioBytes != null) {
            debugPrint('[BusinessAssistant] Read ${audioBytes.length} bytes from recorded file');
          } else {
            debugPrint('[BusinessAssistant] Recorded audio file was missing or empty');
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    if (audioBytes == null || audioBytes.isEmpty) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedLang == 'mr'
                  ? 'कोणताही आवाज रेकॉर्ड झाला नाही, कृपया पुन्हा बोला.'
                  : (_selectedLang == 'en'
                      ? 'No audio was recorded. Please try speaking again.'
                      : 'कोई आवाज़ रिकॉर्ड नहीं हुई, कृपया दोबारा बोलें।'),
            ),
          ),
        );
      }
      return;
    }

    try {
      final result = await _assistantService.transcribeVoice(
        audioBytes: audioBytes,
        language: _selectedLang,
      );

      if (!mounted) return;
      setState(() => _isTranscribing = false);

      if (result['success'] == true && result['transcription'] != null) {
        final transcription = (result['transcription'] as String).trim();
        if (transcription.isNotEmpty) {
          // Populate the input bar so artisan can review/edit before sending
          setState(() {
            _textCtrl.text = transcription;
          });
          _textFocusNode.requestFocus();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedLang == 'mr'
                          ? 'आवाज ओळखला गेला! कृपया तपासून पाठवा (Send).'
                          : (_selectedLang == 'en'
                              ? 'Voice transcribed! Review your question and tap send.'
                              : 'आवाज़ पहचान ली गई! कृपया सवाल जांचें और भेजें।'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final errorMsg = result['friendly_error'] ?? result['error'] ?? 'आवाज़ पहचान में नहीं आई';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.orange.shade800),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranscribing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ट्रांसक्रिप्शन त्रुटि: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isSending) return;

    if (_isRecording) {
      await _stopVoiceRecording();
    }

    if (!mounted) return;
    final auth = context.read<AppAuthProvider>();
    final user = auth.userModel;
    final artisanId = auth.currentArtisanId;

    // Extract recent conversation history (up to last 8 turns)
    final recentHistory = _messages
        .take(_messages.length)
        .toList()
        .reversed
        .take(8)
        .toList()
        .reversed
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'text': m.text,
            })
        .toList();

    // Extract artisan profile context
    final artisanProfile = {
      'name': user?.name,
      'craft': user?.artisanCluster,
      'region': user?.region,
      'experience': '${user?.experienceYears ?? 0} years',
      'story': user?.artisanStory,
    };

    final currentReqId = ++_activeRequestId;

    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isSending = true;
    });
    _textCtrl.clear();
    _scrollToBottom();

    try {
      final res = await _assistantService.askAssistant(
        artisanId: artisanId,
        question: query,
        language: _selectedLang,
        conversationHistory: recentHistory,
        artisanProfile: artisanProfile,
      );

      if (mounted) {
        // Discard stale response if a newer request was dispatched
        if (currentReqId != _activeRequestId) return;

        setState(() {
          _isSending = false;
          final answer = res['answer'] as String? ??
              'माफ़ करें, उत्तर प्राप्त करने में समस्या आई। कृपया दोबारा पूछें।';
          _messages.add(ChatMessage(
            text: answer,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        if (currentReqId != _activeRequestId) return;

        setState(() {
          _isSending = false;
          _messages.add(ChatMessage(
            text: _selectedLang == 'mr'
                ? 'तांत्रिक अडचण आली. कृपया थोड्या वेळाने पुन्हा प्रयत्न करा.'
                : (_selectedLang == 'en'
                    ? 'Technical issue encountered. Please try again shortly.'
                    : 'तकनीकी समस्या आई। कृपया थोड़ी देर बाद प्रयास करें।'),
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    List<String> prompts;
    if (_selectedLang == 'mr') {
      prompts = _quickPromptsMr;
    } else if (_selectedLang == 'en') {
      prompts = _quickPromptsEn;
    } else {
      prompts = _quickPromptsHi;
    }

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedLang == 'mr'
                        ? 'व्यापार सहाय्यक (AI Counselor)'
                        : (_selectedLang == 'en'
                            ? 'AI Business Counselor'
                            : 'व्यापार सहायक (AI Counselor)'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    _selectedLang == 'mr'
                        ? 'हुनरसाथी AI सल्लागार • सक्रिय'
                        : (_selectedLang == 'en'
                            ? 'HunarSathi AI Guide • Active'
                            : 'हुनरसाथी AI बिजनेस गाइड • सक्रिय'),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Language Switcher Dropdown
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white38),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLang,
                dropdownColor: AppTheme.darkIndigo,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                items: const [
                  DropdownMenuItem(value: 'hi', child: Text('🇮🇳 हिंदी', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'mr', child: Text('🇮🇳 मराठी', style: TextStyle(color: Colors.white))),
                  DropdownMenuItem(value: 'en', child: Text('🌐 English', style: TextStyle(color: Colors.white))),
                ],
                onChanged: (val) {
                  if (val != null && val != _selectedLang) {
                    setState(() {
                      _selectedLang = val;
                      _messages.add(_buildWelcomeMessage(val));
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Prompts Carousel
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: Colors.white,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              itemCount: prompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                return ActionChip(
                  label: Text(
                    prompts[i],
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkIndigo),
                  ),
                  backgroundColor: AppTheme.bgParchment,
                  side: BorderSide(color: AppTheme.secondaryOchre.withValues(alpha: 0.5)),
                  onPressed: _isSending ? null : () => _sendMessage(prompts[i]),
                );
              },
            ),
          ),

          const Divider(height: 1, color: AppTheme.borderGrey),

          // Message Bubbles List
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              itemCount: _messages.length + (_isSending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length && _isSending) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[i]);
              },
            ),
          ),

          // Listening Banner (when recording audio)
          if (_isRecording)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border(top: BorderSide(color: Colors.red.shade200)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLang == 'mr'
                              ? 'ऐकत आहोत... (बोलणे सुरू ठेवा)'
                              : (_selectedLang == 'en'
                                  ? 'Listening... (Speak your question)'
                                  : 'सुन रहे हैं... (अपना सवाल बोलें)'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.red.shade900,
                          ),
                        ),
                        Text(
                          _formatDuration(_recordSeconds),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: Text(
                      _selectedLang == 'mr' ? 'पूर्ण करा' : (_selectedLang == 'en' ? 'Done' : 'रोकें'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _stopVoiceRecording,
                  ),
                ],
              ),
            ),

          // Transcribing Indicator Banner
          if (_isTranscribing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.secondaryOchre.withValues(alpha: 0.15),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTerracotta),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLang == 'mr'
                          ? 'आवाजाचे रूपांतरण चालू आहे...'
                          : (_selectedLang == 'en'
                              ? 'Transcribing your voice...'
                              : 'आवाज़ को टेक्स्ट में बदला जा रहा है...'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkIndigo),
                    ),
                  ),
                ],
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Microphone Button
                  IconButton(
                    icon: _isRecording
                        ? ScaleTransition(
                            scale: _pulseAnimation,
                            child: const Icon(Icons.mic, color: Colors.red, size: 28),
                          )
                        : Icon(
                            Icons.mic_none_rounded,
                            color: AppTheme.primaryTerracotta,
                            size: 28,
                          ),
                    tooltip: _isRecording ? 'बोलना समाप्त करें' : 'बोलकर पूछें (Speak)',
                    onPressed: _toggleVoiceRecording,
                  ),
                  const SizedBox(width: 4),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      focusNode: _textFocusNode,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: _selectedLang == 'mr'
                            ? 'व्यवसाय किंवा हस्तकलेविषयी विचारा...'
                            : (_selectedLang == 'en'
                                ? 'Ask a craft business question...'
                                : 'व्यापार या शिल्प से जुड़ा सवाल लिखें...'),
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        filled: true,
                        fillColor: AppTheme.bgParchment,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send Button
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: _isSending ? Colors.grey : AppTheme.primaryTerracotta,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    onPressed: _isSending ? null : () => _sendMessage(_textCtrl.text),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: msg.isUser ? AppTheme.darkIndigo : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: Border.all(
            color: msg.isUser
                ? Colors.transparent
                : (msg.isError ? Colors.red.shade300 : AppTheme.secondaryOchre.withValues(alpha: 0.3)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.secondaryOchre, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _selectedLang == 'mr'
                        ? 'हुनरसाथी व्यापार सहाय्यक'
                        : (_selectedLang == 'en' ? 'HunarSathi Business Guide' : 'हुनरसाथी व्यापार सहायक'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTerracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            SelectableText(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: msg.isUser ? Colors.white : Colors.grey.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryTerracotta),
            ),
            const SizedBox(width: 10),
            Text(
              _selectedLang == 'mr'
                  ? 'व्यापार सहाय्यक विचार करत आहे...'
                  : (_selectedLang == 'en'
                      ? 'Counselor is thinking...'
                      : 'व्यापार सहायक विचार कर रहा है...'),
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
