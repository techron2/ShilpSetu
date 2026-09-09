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

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.languagePreference = 'en',
    this.artisanCluster = '',
    this.region = '',
  });

  bool get isArtisan => role == 'artisan';
  bool get isBuyer   => role == 'buyer';

  /// Creates a [UserModel] from a Firestore document map or API response.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid:                json['uid']?.toString() ?? '',
      name:               json['name']?.toString() ?? '',
      email:              json['email']?.toString() ?? '',
      role:               json['role']?.toString() ?? 'buyer',
      phone:              json['phone_number']?.toString() ?? json['phone']?.toString() ?? '',
      languagePreference: json['language_preference']?.toString() ?? 'en',
      artisanCluster:     json['artisan_cluster']?.toString() ?? '',
      region:             json['region']?.toString() ?? '',
    );
  }

  /// Converts this [UserModel] to a JSON map for Firestore / API writes.
  Map<String, dynamic> toJson() => {
    'uid':                 uid,
    'name':                name,
    'email':               email,
    'role':                role,
    'phone':               phone,
    'phone_number':        phone,
    'language_preference': languagePreference,
    'artisan_cluster':     artisanCluster,
    'region':              region,
  };

  UserModel copyWith({
    String? name,
    String? phone,
    String? languagePreference,
    String? artisanCluster,
    String? region,
    String? role,
  }) {
    return UserModel(
      uid:                uid,
      email:              email,
      name:               name               ?? this.name,
      role:               role               ?? this.role,
      phone:              phone              ?? this.phone,
      languagePreference: languagePreference ?? this.languagePreference,
      artisanCluster:     artisanCluster     ?? this.artisanCluster,
      region:             region             ?? this.region,
    );
  }

  @override
  String toString() => 'UserModel(uid: $uid, name: $name, role: $role)';
}
