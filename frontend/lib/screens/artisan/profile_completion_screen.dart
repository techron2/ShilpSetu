import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../main_screen.dart';

class ProfileCompletionScreen extends StatefulWidget {
  final int initialStep;
  const ProfileCompletionScreen({super.key, this.initialStep = 0});

  @override
  State<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends State<ProfileCompletionScreen>
    with SingleTickerProviderStateMixin {
  late int _currentStep; // 0: Basic, 1: Personal, 2: Photos, 3: Story

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();

  String _gender = 'Male';
  String _maritalStatus = 'Married';

  // Photo state
  Uint8List? _profileImageBytes;
  String? _profileImageUrl;
  Uint8List? _coverImageBytes;
  String? _coverImageUrl;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Voice recording state
  bool _isRecording = false;
  bool _isProcessingVoice = false;
  int _recordSeconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(0, 3);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Pre-fill existing user info if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AppAuthProvider>().userModel;
      if (user != null) {
        if (user.name.isNotEmpty) _nameCtrl.text = user.name;
        if (user.phone.isNotEmpty) _phoneCtrl.text = user.phone;
        if (user.dateOfBirth.isNotEmpty) _dobCtrl.text = user.dateOfBirth;
        if (user.gender.isNotEmpty) _gender = user.gender;
        if (user.maritalStatus.isNotEmpty) _maritalStatus = user.maritalStatus;
        if (user.experienceYears > 0) _expCtrl.text = user.experienceYears.toString();
        if (user.artisanStory.isNotEmpty) _storyCtrl.text = user.artisanStory;
        if (user.profilePhotoUrl.isNotEmpty) _profileImageUrl = user.profilePhotoUrl;
        if (user.coverPhotoUrl.isNotEmpty) _coverImageUrl = user.coverPhotoUrl;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _expCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  // ── Voice Recording Logic ──────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: '',
      );

      _pulseController.repeat(reverse: true);
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _recordSeconds++);
      });
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
    }
  }

  Future<void> _stopVoiceRecordingAndProcess() async {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    final currentLangCode = context.read<LanguageProvider>().currentLanguageCode;
    Uint8List? audioBytes;

    try {
      final audioPath = await _audioRecorder.stop();
      if (audioPath != null && audioPath.isNotEmpty) {
        if (kIsWeb) {
          final res = await http.get(Uri.parse(audioPath));
          if (res.statusCode == 200) {
            audioBytes = res.bodyBytes;
          }
        }
      }
    } catch (e) {
      debugPrint('Error stopping audio recorder: $e');
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isProcessingVoice = true;
    });

    final result = await ProfileService.instance.voiceToProfile(
      audioBytes: audioBytes,
      language: currentLangCode,
    );

    if (!mounted) return;
    setState(() => _isProcessingVoice = false);

    if (result['success'] == true) {
      _applyExtractedProfile(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['friendly_error'] ?? 'Could not extract voice details'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// Auto-populates all form fields from AI extracted profile
  void _applyExtractedProfile(Map<String, dynamic> data) {
    if (data['full_name'] != null && data['full_name'].toString().isNotEmpty) {
      _nameCtrl.text = data['full_name'].toString();
    }
    if (data['date_of_birth'] != null && data['date_of_birth'].toString().isNotEmpty) {
      _dobCtrl.text = data['date_of_birth'].toString();
    }
    if (data['phone_number'] != null && data['phone_number'].toString().isNotEmpty) {
      _phoneCtrl.text = data['phone_number'].toString();
    }
    if (data['gender'] != null) {
      final g = data['gender'].toString().toLowerCase();
      if (g.contains('female')) {
        _gender = 'Female';
      } else if (g.contains('male')) {
        _gender = 'Male';
      } else {
        _gender = 'Other';
      }
    }
    if (data['marital_status'] != null) {
      final m = data['marital_status'].toString().toLowerCase();
      if (m.contains('single')) {
        _maritalStatus = 'Single';
      } else {
        _maritalStatus = 'Married';
      }
    }
    if (data['experience_years'] != null) {
      _expCtrl.text = data['experience_years'].toString();
    }
    if (data['story'] != null && data['story'].toString().isNotEmpty) {
      _storyCtrl.text = data['story'].toString();
    }

    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Voice details extracted! Please review and save.'),
          backgroundColor: AppTheme.successGreen,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Image Picker ──────────────────────────────────────────────────────────

  Future<void> _pickPhoto({required bool isProfile}) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final lang = context.read<LanguageProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isProfile ? lang.getText('profile_photo_label') : lang.getText('cover_photo_label'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryTerracotta),
                  title: Text(lang.getText('take_photo_option')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setState(() {
                        if (isProfile) {
                          _profileImageBytes = bytes;
                        } else {
                          _coverImageBytes = bytes;
                        }
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppTheme.secondaryOchre),
                  title: Text(lang.getText('gallery_option')),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setState(() {
                        if (isProfile) {
                          _profileImageBytes = bytes;
                        } else {
                          _coverImageBytes = bytes;
                        }
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Save & Submit ──────────────────────────────────────────────────────────

  Future<void> _submitProfile() async {
    final auth = context.read<AppAuthProvider>();
    final uid = auth.currentArtisanId;

    setState(() => _isSaving = true);

    String? profileUrl = _profileImageUrl;
    if (_profileImageBytes != null) {
      profileUrl = await ProfileService.instance.uploadImage(
        _profileImageBytes!,
        'avatar_${uid.substring(0, 6)}.jpg',
      );
    }

    String? coverUrl = _coverImageUrl;
    if (_coverImageBytes != null) {
      coverUrl = await ProfileService.instance.uploadImage(
        _coverImageBytes!,
        'cover_${uid.substring(0, 6)}.jpg',
      );
    }

    final payload = {
      'name': _nameCtrl.text.trim(),
      'date_of_birth': _dobCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'phone_number': _phoneCtrl.text.trim(),
      'gender': _gender,
      'marital_status': _maritalStatus,
      'experience_years': int.tryParse(_expCtrl.text.trim()) ?? 0,
      'story': _storyCtrl.text.trim(),
      'artisan_story': _storyCtrl.text.trim(),
      'profile_photo_url': profileUrl ?? '',
      'cover_photo_url': coverUrl ?? '',
      'is_profile_completed': true,
    };

    final res = await ProfileService.instance.saveProfile(uid, payload);
    setState(() => _isSaving = false);

    if (res['success'] == true && mounted) {
      // Update local UserModel
      if (auth.userModel != null) {
        final updated = auth.userModel!.copyWith(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          dateOfBirth: _dobCtrl.text.trim(),
          gender: _gender,
          maritalStatus: _maritalStatus,
          experienceYears: int.tryParse(_expCtrl.text.trim()) ?? 0,
          artisanStory: _storyCtrl.text.trim(),
          profilePhotoUrl: profileUrl ?? '',
          coverPhotoUrl: coverUrl ?? '',
          isProfileCompleted: true,
        );
        auth.updateUserModel(updated);
      }

      final lang = context.read<LanguageProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lang.getText('profile_saved_success')),
          backgroundColor: AppTheme.successGreen,
        ),
      );

      context.read<NavigationProvider>().setIndex(0);
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['error'] ?? 'Error saving profile'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _skip() {
    context.read<NavigationProvider>().setIndex(0);
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  // ── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgParchment,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          lang.getText('profile_completion_title'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              lang.getText('skip_for_now'),
              style: const TextStyle(
                color: AppTheme.primaryTerracotta,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Master Voice-Fill Banner ─────────────────────────────────
              _buildMasterVoiceBanner(lang),
              const SizedBox(height: 20),

              // ── Step Indicators ──────────────────────────────────────────
              _buildStepIndicator(lang),
              const SizedBox(height: 20),

              // ── Step Content ─────────────────────────────────────────────
              if (_currentStep == 0) _buildStepBasicInfo(lang),
              if (_currentStep == 1) _buildStepPersonalInfo(lang),
              if (_currentStep == 2) _buildStepPhotos(lang),
              if (_currentStep == 3) _buildStepStory(lang),

              const SizedBox(height: 30),

              // ── Action Buttons ───────────────────────────────────────────
              _buildNavigationButtons(lang),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasterVoiceBanner(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryTerracotta.withValues(alpha: 0.12),
            AppTheme.secondaryOchre.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryTerracotta.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ScaleTransition(
                scale: _isRecording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : AppTheme.primaryTerracotta,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.redAccent : AppTheme.primaryTerracotta)
                            .withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isRecording
                          ? '${lang.getText('voice_listening')} (${_recordSeconds}s)'
                          : _isProcessingVoice
                              ? lang.getText('voice_processing')
                              : lang.getText('voice_fill_banner_title'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.darkIndigo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang.getText('voice_fill_banner_sub'),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _isRecording ? Colors.redAccent : AppTheme.primaryTerracotta,
              minimumSize: const Size(double.infinity, 44),
            ),
            icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 20),
            label: Text(
              _isRecording ? 'Stop Recording' : lang.getText('voice_fill_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: _isProcessingVoice
                ? null
                : () {
                    if (_isRecording) {
                      _stopVoiceRecordingAndProcess();
                    } else {
                      _startVoiceRecording();
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(LanguageProvider lang) {
    final steps = [
      lang.getText('step_basic_info'),
      lang.getText('step_personal_info'),
      lang.getText('step_photos'),
      lang.getText('step_story'),
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isActive = _currentStep == index;
        final isCompleted = _currentStep > index;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _currentStep = index),
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isCompleted ? AppTheme.primaryTerracotta : Colors.grey.shade300,
                        ),
                      ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isCompleted || isActive
                            ? AppTheme.primaryTerracotta
                            : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive ? Colors.white : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          color: isCompleted ? AppTheme.primaryTerracotta : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  steps[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive ? AppTheme.primaryTerracotta : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ── Step 0: Basic Info ─────────────────────────────────────────────────────

  Widget _buildStepBasicInfo(LanguageProvider lang) {
    return _buildCardWrapper(
      children: [
        _buildTextField(
          controller: _nameCtrl,
          label: lang.getText('full_name'),
          hint: 'Radha Devi / Rameshwar Prajapati',
          icon: Icons.person_rounded,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _dobCtrl,
          label: lang.getText('dob_label'),
          hint: '1980-05-12',
          icon: Icons.calendar_month_rounded,
          suffix: IconButton(
            icon: const Icon(Icons.event, color: AppTheme.primaryTerracotta),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime(1985),
                firstDate: DateTime(1940),
                lastDate: DateTime(2010),
              );
              if (date != null) {
                _dobCtrl.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _phoneCtrl,
          label: lang.getText('phone'),
          hint: '+91 98765 43210',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  // ── Step 1: Personal & Craft Info ──────────────────────────────────────────

  Widget _buildStepPersonalInfo(LanguageProvider lang) {
    return _buildCardWrapper(
      children: [
        // Gender Selector
        Text(
          lang.getText('gender_label'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildChoiceChip(
              label: lang.getText('gender_male'),
              selected: _gender == 'Male',
              onSelected: (_) => setState(() => _gender = 'Male'),
            ),
            const SizedBox(width: 8),
            _buildChoiceChip(
              label: lang.getText('gender_female'),
              selected: _gender == 'Female',
              onSelected: (_) => setState(() => _gender = 'Female'),
            ),
            const SizedBox(width: 8),
            _buildChoiceChip(
              label: lang.getText('gender_other'),
              selected: _gender == 'Other',
              onSelected: (_) => setState(() => _gender = 'Other'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Marital Status Selector
        Text(
          lang.getText('marital_status_label'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildChoiceChip(
              label: lang.getText('status_married'),
              selected: _maritalStatus == 'Married',
              onSelected: (_) => setState(() => _maritalStatus = 'Married'),
            ),
            const SizedBox(width: 8),
            _buildChoiceChip(
              label: lang.getText('status_single'),
              selected: _maritalStatus == 'Single',
              onSelected: (_) => setState(() => _maritalStatus = 'Single'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Experience Years
        _buildTextField(
          controller: _expCtrl,
          label: lang.getText('experience_years_label'),
          hint: '15',
          icon: Icons.workspace_premium_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ── Step 2: Photos ─────────────────────────────────────────────────────────

  Widget _buildStepPhotos(LanguageProvider lang) {
    return _buildCardWrapper(
      children: [
        // Profile Photo Avatar
        Text(
          lang.getText('profile_photo_label'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 12),
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryTerracotta.withValues(alpha: 0.12),
                  border: Border.all(color: AppTheme.primaryTerracotta, width: 2),
                  image: _profileImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_profileImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_profileImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: _profileImageBytes == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 55, color: AppTheme.primaryTerracotta)
                    : null,
              ),
              InkWell(
                onTap: () => _pickPhoto(isProfile: true),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryTerracotta,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Divider(color: AppTheme.borderGrey),
        const SizedBox(height: 16),

        // Cover Photo Banner
        Text(
          lang.getText('cover_photo_label'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _pickPhoto(isProfile: false),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: AppTheme.secondaryOchre.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.secondaryOchre.withValues(alpha: 0.5)),
              image: _coverImageBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_coverImageBytes!),
                      fit: BoxFit.cover,
                    )
                  : (_coverImageUrl != null && _coverImageUrl!.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(_coverImageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null),
            ),
            child: _coverImageBytes == null && (_coverImageUrl == null || _coverImageUrl!.isEmpty)
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_rounded, size: 36, color: AppTheme.secondaryOchre),
                      const SizedBox(height: 6),
                      Text(
                        lang.getText('upload_photo_prompt'),
                        style: const TextStyle(
                          color: AppTheme.darkIndigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : Container(
                    alignment: Alignment.topRight,
                    padding: const EdgeInsets.all(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // ── Step 3: Artisan Story ──────────────────────────────────────────────────

  Widget _buildStepStory(LanguageProvider lang) {
    return _buildCardWrapper(
      children: [
        Text(
          lang.getText('story_field_label'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 6),
        Text(
          lang.getText('story_field_hint'),
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _storyCtrl,
          maxLines: 7,
          minLines: 4,
          decoration: InputDecoration(
            hintText: 'मेरा नाम ... है और मेरी यह शिल्प यात्रा...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  // ── Helpers & Common Widgets ───────────────────────────────────────────────

  Widget _buildCardWrapper({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.darkIndigo),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.primaryTerracotta, size: 20),
            suffixIcon: suffix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderGrey),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.primaryTerracotta, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: AppTheme.primaryTerracotta,
      backgroundColor: const Color(0xFFF3F4F6),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF4B5563),
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _buildNavigationButtons(LanguageProvider lang) {
    final isLast = _currentStep == 3;

    return Row(
      children: [
        if (_currentStep > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(lang.getText('back_btn')),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryTerracotta,
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isSaving
                ? null
                : () {
                    if (isLast) {
                      _submitProfile();
                    } else {
                      setState(() => _currentStep++);
                    }
                  },
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    isLast ? lang.getText('save_profile_btn') : lang.getText('next_btn'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }
}
