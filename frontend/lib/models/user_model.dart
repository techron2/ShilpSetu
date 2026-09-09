/// Represents a ShilpSetu user profile stored in Firestore "users" collection.
///
/// This is separate from Firebase Auth — Auth handles credentials,
/// Firestore "users" handles display info and role.
class UserModel {
  final String uid;
  final String name;
  final String email;

  /// Either "artisan" or "buyer".
  final String role;

  final String phone;
  final String languagePreference;
  final String artisanCluster;
  final String region;

  // New Profile Completion Fields
  final String dateOfBirth;
  final String gender;
  final String maritalStatus;
  final int    experienceYears;
  final String profilePhotoUrl;
  final String coverPhotoUrl;
  final String artisanStory;
  final bool   isProfileCompleted;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.languagePreference = 'en',
    this.artisanCluster = '',
    this.region = '',
    this.dateOfBirth = '',
    this.gender = '',
    this.maritalStatus = '',
    this.experienceYears = 0,
    this.profilePhotoUrl = '',
    this.coverPhotoUrl = '',
    this.artisanStory = '',
    this.isProfileCompleted = false,
  });

  bool get isArtisan => role == 'artisan';
  bool get isBuyer   => role == 'buyer';

  /// Creates a [UserModel] from a Firestore document map or API response.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid:                 json['uid']?.toString() ?? '',
      name:                json['name']?.toString() ?? '',
      email:               json['email']?.toString() ?? '',
      role:                json['role']?.toString() ?? 'buyer',
      phone:               json['phone_number']?.toString() ?? json['phone']?.toString() ?? '',
      languagePreference:  json['language_preference']?.toString() ?? 'en',
      artisanCluster:      json['artisan_cluster']?.toString() ?? '',
      region:              json['region']?.toString() ?? '',
      dateOfBirth:         json['date_of_birth']?.toString() ?? '',
      gender:              json['gender']?.toString() ?? '',
      maritalStatus:       json['marital_status']?.toString() ?? '',
      experienceYears:     int.tryParse(json['experience_years']?.toString() ?? '') ?? 0,
      profilePhotoUrl:     json['profile_photo_url']?.toString() ?? '',
      coverPhotoUrl:       json['cover_photo_url']?.toString() ?? '',
      artisanStory:        json['artisan_story']?.toString() ?? json['story']?.toString() ?? '',
      isProfileCompleted:  json['is_profile_completed'] == true,
    );
  }

  /// Converts this [UserModel] to a JSON map for Firestore / API writes.
  Map<String, dynamic> toJson() => {
    'uid':                  uid,
    'name':                 name,
    'email':                email,
    'role':                 role,
    'phone':                phone,
    'phone_number':         phone,
    'language_preference':  languagePreference,
    'artisan_cluster':      artisanCluster,
    'region':               region,
    'date_of_birth':        dateOfBirth,
    'gender':               gender,
    'marital_status':       maritalStatus,
    'experience_years':     experienceYears,
    'profile_photo_url':    profilePhotoUrl,
    'cover_photo_url':      coverPhotoUrl,
    'artisan_story':        artisanStory,
    'story':                artisanStory,
    'is_profile_completed': isProfileCompleted,
  };

  UserModel copyWith({
    String? name,
    String? phone,
    String? languagePreference,
    String? artisanCluster,
    String? region,
    String? role,
    String? dateOfBirth,
    String? gender,
    String? maritalStatus,
    int?    experienceYears,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
    String? artisanStory,
    bool?   isProfileCompleted,
  }) {
    return UserModel(
      uid:                 uid,
      email:               email,
      name:                name                ?? this.name,
      role:                role                ?? this.role,
      phone:               phone               ?? this.phone,
      languagePreference:  languagePreference  ?? this.languagePreference,
      artisanCluster:      artisanCluster      ?? this.artisanCluster,
      region:              region              ?? this.region,
      dateOfBirth:         dateOfBirth         ?? this.dateOfBirth,
      gender:              gender              ?? this.gender,
      maritalStatus:       maritalStatus       ?? this.maritalStatus,
      experienceYears:     experienceYears     ?? this.experienceYears,
      profilePhotoUrl:     profilePhotoUrl     ?? this.profilePhotoUrl,
      coverPhotoUrl:       coverPhotoUrl       ?? this.coverPhotoUrl,
      artisanStory:        artisanStory        ?? this.artisanStory,
      isProfileCompleted:  isProfileCompleted   ?? this.isProfileCompleted,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, role: $role, completed: $isProfileCompleted)';
}
