import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Wraps Firebase Auth (email/password) and syncs profile to Firestore "users".
///
/// - [signUpWithEmail]: creates Auth account + Firestore profile
/// - [signInWithEmail]: authenticates via Firebase Auth
/// - [signOut]: clears the session
/// - [fetchUserModel]: reads profile from Firestore
class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// The currently signed-in Firebase user, or null if not authenticated.
  User? get currentUser {
    if (Firebase.apps.isEmpty) return null;
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Stream of auth state changes (signed in / signed out).
  Stream<User?> get authStateChanges {
    if (Firebase.apps.isEmpty) return const Stream.empty();
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // ---------------------------------------------------------------------------
  // Sign Up
  // ---------------------------------------------------------------------------

  /// Creates a new account and saves the user profile to Firestore.
  ///
  /// [name] — display name  
  /// [email] — email address  
  /// [password] — min 6 characters (Firebase requirement)  
  /// [role] — "artisan" or "buyer"
  /// Creates a new account and saves the user profile to Firestore.
  ///
  /// [name] — display name  
  /// [email] — email address  
  /// [password] — min 6 characters (Firebase requirement)  
  /// [role] — "artisan" or "buyer"
  /// [phoneNumber] — required phone number
  Future<UserModel> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    required String role,
    required String phoneNumber,
    String? languagePreference,
  }) async {
    // 1. Create Firebase Auth account
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user!;

    // 2. Update display name in Auth profile
    try {
      await user.updateDisplayName(name.trim());
    } catch (_) {}

    // 3. Build Firestore profile document
    final userModel = UserModel(
      uid:                user.uid,
      name:               name.trim(),
      email:              email.trim(),
      role:               role,
      phone:              phoneNumber.trim(),
      languagePreference: languagePreference ?? 'hi',
    );

    // 4. Save to Firestore "users" collection
    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toJson());
    } catch (e) {
      // Non-fatal if Firestore rules are not yet published
    }

    return userModel;
  }

  // ---------------------------------------------------------------------------
  // Password Reset
  // ---------------------------------------------------------------------------

  /// Sends a password reset email via Firebase Auth.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ---------------------------------------------------------------------------
  // Sign In
  // ---------------------------------------------------------------------------

  /// Authenticates with email and password.
  ///
  /// Throws [FirebaseAuthException] on invalid credentials.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user!;
  }

  /// Searches Firestore "users" collection for a profile matching [phoneNumber].
  Future<UserModel?> findUserByPhoneNumber(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\s+'), '').trim();
    if (cleanPhone.isEmpty) return null;

    // Check phone_number and phone fields
    final query1 = await _firestore
        .collection('users')
        .where('phone_number', isEqualTo: cleanPhone)
        .limit(1)
        .get();

    if (query1.docs.isNotEmpty) {
      return UserModel.fromJson(query1.docs.first.data());
    }

    final query2 = await _firestore
        .collection('users')
        .where('phone', isEqualTo: cleanPhone)
        .limit(1)
        .get();

    if (query2.docs.isNotEmpty) {
      return UserModel.fromJson(query2.docs.first.data());
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Sign Out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ---------------------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------------------

  /// Reads the Firestore "users" document for the given [uid].
  ///
  /// Returns null if the document does not yet exist.
  Future<UserModel?> fetchUserModel(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return UserModel.fromJson(doc.data()!);
  }

  /// Updates profile fields in the Firestore "users" document.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> fields) async {
    await _firestore.collection('users').doc(uid).update(fields);
  }

  // ---------------------------------------------------------------------------
  // Human-readable error messages
  // ---------------------------------------------------------------------------

  /// Converts a [FirebaseAuthException] code to a friendly message
  /// suitable for displaying to low-digital-literacy users.
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'configuration-not-found':
        return 'Email/Password authentication is not yet enabled in your Firebase Console. Go to Build > Authentication > Sign-in method and enable Email/Password.';
      default:
        return e.message ?? 'Something went wrong. Please try again.';
    }
  }
}
