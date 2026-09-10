import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/assistant_service.dart';
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
  const BusinessAssistantScreen({super.key});

  @override
  State<BusinessAssistantScreen> createState() => _BusinessAssistantScreenState();
}

class _BusinessAssistantScreenState extends State<BusinessAssistantScreen> {
  final AssistantService _assistantService = AssistantService();
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isListening = false;
  String _selectedLang = 'hi'; // 'hi' or 'en'

  final List<String> _quickPromptsHi = [
    '🪔 दीवाली पर सही दाम क्या रखें?',
    '📈 बिक्री और ऑर्डर कैसे बढ़ाएं?',
    '📦 सुरक्षित और सुंदर पैकेजिंग कैसे करें?',
    '🏙️ बड़े शहरों के ग्राहकों को कैसे आकर्षित करें?',
    '💰 क्या मुझे कॉम्बो उपहार सेट बनाना चाहिए?'
  ];

  final List<String> _quickPromptsEn = [
    '🪔 What pricing strategy should I use for Diwali?',
    '📈 How can I increase orders for my craft?',
    '📦 What are safe eco-friendly packaging tips?',
    '🏙️ How to attract buyers in metropolitan cities?',
    '💰 Should I create gift bundle sets?'
  ];

  @override
  void initState() {
    super.initState();
    // Welcome message from AI Business Assistant
    _messages.add(
      ChatMessage(
        text: 'नमस्ते शिल्पकार जी! 🙏 मैं आपका KalaVistar व्यापार सहायक हूँ। '
            'आप मुझसे अपने शिल्प की कीमत, बिक्री बढ़ाने के तरीके, त्योहारों के ऑफर या पैकेजिंग के बारे में कोई भी सवाल पूछ सकते हैं।',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _textCtrl.dispose();
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

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty || _isSending) return;

    final auth = context.read<AppAuthProvider>();
    final artisanId = auth.firebaseUser?.uid ?? 'artisan_001';

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
      );

      if (mounted) {
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
        setState(() {
          _isSending = false;
          _messages.add(ChatMessage(
            text: 'तकनीकी समस्या आई। कृपया थोड़ी देर बाद प्रयास करें।',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _simulateVoiceRecording() {
    // Interactive voice prompt for artisans with low digital literacy
    setState(() => _isListening = true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: AppTheme.primaryTerracotta, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'बोलकर सवाल पूछें (Speak Your Question)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.darkIndigo,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'जैसे: "दीवाली के समय मुझे अपने उत्पादों के दाम क्या रखने चाहिए?"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.record_voice_over, size: 16),
                    label: const Text('दीवाली पर क्या दाम रखें?'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendMessage('दीवाली के मौसम में मुझे अपने शिल्पों की कीमत क्या रखनी चाहिए?');
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.record_voice_over, size: 16),
                    label: const Text('बिक्री कैसे बढ़ाएं?'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _sendMessage('ऑनलाइन बिक्री और नए ग्राहक आकर्षित करने के सबसे अच्छे तरीके क्या हैं?');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) setState(() => _isListening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompts = _selectedLang == 'hi' ? _quickPromptsHi : _quickPromptsEn;

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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'व्यापार सहायक (AI Counselor)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  Text(
                    'KalaVistar AI बिजनेस गाइड • सक्रिय',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Language switcher button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(_selectedLang == 'hi' ? '🇮🇳 हिंदी' : '🌐 English'),
              selected: true,
              selectedColor: Colors.white.withValues(alpha: 0.2),
              labelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              side: const BorderSide(color: Colors.white38),
              onSelected: (_) {
                setState(() {
                  _selectedLang = _selectedLang == 'hi' ? 'en' : 'hi';
                });
              },
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
                  label: Text(prompts[i], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: AppTheme.bgParchment,
                  side: BorderSide(color: AppTheme.secondaryOchre.withValues(alpha: 0.5)),
                  onPressed: () => _sendMessage(prompts[i]),
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
                  // Microphone Button for low-literacy voice input
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none_rounded,
                      color: AppTheme.primaryTerracotta,
                      size: 28,
                    ),
                    tooltip: 'बोलकर पूछें (Speak)',
                    onPressed: _simulateVoiceRecording,
                  ),
                  const SizedBox(width: 4),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: _selectedLang == 'hi'
                            ? 'व्यापार से जुड़ा सवाल लिखें...'
                            : 'Ask a business question...',
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
                      backgroundColor: AppTheme.primaryTerracotta,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                    onPressed: () => _sendMessage(_textCtrl.text),
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
          maxWidth: MediaQuery.of(context).size.width * 0.82,
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
                    'KalaVistar व्यापार सहायक',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryTerracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
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
              _selectedLang == 'hi' ? 'व्यापार सहायक विचार कर रहा है...' : 'Counselor is thinking...',
              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
