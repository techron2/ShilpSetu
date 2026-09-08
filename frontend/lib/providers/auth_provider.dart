import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Auth state for the whole app.
///
/// Named [AppAuthProvider] to avoid name clash with firebase_auth's AuthProvider.
///
/// Exposes:
/// - [firebaseUser] — the raw Firebase Auth user (null = signed out)
/// - [userModel] — the Firestore profile (null until loaded)
/// - [isLoading] — true while an async auth op is in progress
/// - [errorMessage] — friendly error string from the last failed op
class AppAuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User?      _firebaseUser;
  UserModel? _userModel;
  bool       _isLoading = false;
  String?    _errorMessage;

  // ── Getters ──────────────────────────────────────────────────────────────
  User?      get firebaseUser  => _firebaseUser;
  UserModel? get userModel     => _userModel;
  bool       get isLoading     => _isLoading;
  String?    get errorMessage  => _errorMessage;
  bool       get isSignedIn    => _firebaseUser != null;

  AppAuthProvider() {
    // Only subscribe to auth changes when Firebase is actually initialized.
    // In placeholder mode (no real credentials), this is a no-op.
    if (Firebase.apps.isNotEmpty) {
      _authService.authStateChanges.listen(_onAuthStateChanged);
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────
  Future<void> _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    _userModel    = null;
    if (user != null) {
      try {
        _userModel = await _authService.fetchUserModel(user.uid);
      } catch (_) {
        // Profile may not exist yet (e.g. just after creating the auth account)
      }
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Public actions ────────────────────────────────────────────────────────

  /// Sign up with email/password and a chosen role.
  /// Returns `true` on success, `false` on error (check [errorMessage]).
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      _userModel = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        role: role,
      );
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(AuthService.friendlyError(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Unexpected error: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Sign in with email/password.
  /// Returns `true` on success, `false` on error (check [errorMessage]).
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(AuthService.friendlyError(e));
      _setLoading(false);
      return false;
    } catch (e) {
      _setError('Unexpected error: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Sign out and clear local state.
  Future<void> signOut() async {
    await _authService.signOut();
    _userModel    = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Reload the Firestore profile for the current user.
  Future<void> reloadProfile() async {
    if (_firebaseUser == null) return;
    try {
      _userModel = await _authService.fetchUserModel(_firebaseUser!.uid);
      notifyListeners();
    } catch (_) {}
  }
}
