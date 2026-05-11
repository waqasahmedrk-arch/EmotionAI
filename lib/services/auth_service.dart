// services/auth_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your models
import '../models/user_model.dart';
import '../models/auth_response.dart';

// Auth Service
class AuthService with ChangeNotifier {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user_data';
  static const String _isGuestKey = 'is_guest';

  User? _currentUser;
  String? _token;
  String? _refreshToken;
  bool _isGuest = false;
  bool _isLoading = false;

  // Firebase instances
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isGuest => _isGuest;

  AuthService() {
    _loadAuthData();
  }

  // Load authentication data from shared preferences
  Future<void> _loadAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _refreshToken = prefs.getString(_refreshTokenKey);
      _isGuest = prefs.getBool(_isGuestKey) ?? false;

      final userJson = prefs.getString(_userKey);
      if (userJson != null) {
        _currentUser = User.fromJson(json.decode(userJson));
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading auth data: $e');
      }
    }
  }

  // Save authentication data to shared preferences
  Future<void> _saveAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString(_tokenKey, _token!);
      }
      if (_refreshToken != null) {
        await prefs.setString(_refreshTokenKey, _refreshToken!);
      }
      if (_currentUser != null) {
        await prefs.setString(_userKey, json.encode(_currentUser!.toJson()));
      }
      await prefs.setBool(_isGuestKey, _isGuest);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving auth data: $e');
      }
    }
  }

  // Clear authentication data
  Future<void> _clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userKey);
      await prefs.remove(_isGuestKey);
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing auth data: $e');
      }
    }
  }

  // Set guest user from GuestLoginScreen
  void setGuestUser(String userName, {String? age, String? gender}) {
    final guestUser = User(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      name: userName,
      email: 'guest@example.com',
      isGuest: true,
      createdAt: DateTime.now(),
    );

    _currentUser = guestUser;
    _token = null;
    _refreshToken = null;
    _isGuest = true;

    _saveAuthData();
    notifyListeners();
  }

  // FIREBASE SIGNUP WITH EMAIL VERIFICATION
  Future<AuthResponse> signUp(String name, String email, String password) async {
    _setLoading(true);

    try {
      // Create user with Firebase Authentication
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('User creation failed');
      }

      // Update display name
      await firebaseUser.updateDisplayName(name);

      // Send email verification
      await firebaseUser.sendEmailVerification();

      // Store user data in Firestore with isVerified = false
      await _firestore.collection('users').doc(firebaseUser.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isGuest': false,
        'isVerified': false, // Set to false initially
      });

      // DON'T sign out - keep user signed in for resending verification email
      // User will be signed out when they go back to login screen

      if (kDebugMode) {
        print('Signup successful. Verification email sent to $email');
      }

      return AuthResponse(
        success: true,
        message: 'Account created successfully. Please verify your email.',
        requiresVerification: true,
      );

    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'email-already-in-use':
          errorMessage = 'This email is already registered.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use at least 6 characters.';
          break;
        default:
          errorMessage = e.message ?? 'Sign up failed';
      }

      if (kDebugMode) {
        print('Firebase Auth Error: ${e.code} - ${e.message}');
      }

      return AuthResponse(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Sign up failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Reload current Firebase user
  Future<void> reloadCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
    } catch (e) {
      if (kDebugMode) {
        print('Error reloading user: $e');
      }
    }
  }

  // Check if email is verified
  Future<bool> checkEmailVerified() async {
    try {
      // Reload user to get fresh data from Firebase
      await _firebaseAuth.currentUser?.reload();
      final user = _firebaseAuth.currentUser;

      if (user != null && user.emailVerified) {
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking email verification: $e');
      }
      return false;
    }
  }

  // Sign out unverified user (called when leaving verification screen)
  Future<void> signOutUnverifiedUser() async {
    try {
      if (_firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
        if (kDebugMode) {
          print('Unverified user signed out');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out unverified user: $e');
      }
    }
  }

  // Resend verification email
  Future<void> resendVerificationEmail() async {
    try {
      // First, try to get the current user from Firebase Auth
      final user = _firebaseAuth.currentUser;

      if (user == null) {
        // If no current user, we need to sign in again temporarily
        // This shouldn't happen, but just in case
        throw Exception('No user is currently signed in. Please try signing up again.');
      }

      // Reload user to get fresh state
      await user.reload();

      // Check if already verified
      if (user.emailVerified) {
        throw Exception('Email is already verified!');
      }

      // Send verification email
      await user.sendEmailVerification();

      if (kDebugMode) {
        print('Verification email sent successfully to ${user.email}');
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Firebase error resending verification email: ${e.code} - ${e.message}');
      }

      // Handle specific Firebase errors
      if (e.code == 'too-many-requests') {
        throw Exception('Too many requests. Please wait a moment before trying again.');
      }

      throw Exception(e.message ?? 'Failed to send verification email');
    } catch (e) {
      if (kDebugMode) {
        print('Error resending verification email: $e');
      }
      rethrow;
    }
  }

  // FIREBASE LOGIN WITH EMAIL VERIFICATION CHECK
  Future<AuthResponse> login(String email, String password) async {
    _setLoading(true);

    try {
      // Sign in with Firebase Authentication
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Login failed');
      }

      // Check if email is verified
      if (!firebaseUser.emailVerified) {
        // Sign out user
        await _firebaseAuth.signOut();

        return AuthResponse(
          success: false,
          message: 'Please verify your email before logging in.',
          requiresVerification: true,
        );
      }

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();

      final userData = userDoc.data() ?? {};

      // Update isVerified in Firestore if not already set
      if (userData['isVerified'] != true) {
        await _firestore.collection('users').doc(firebaseUser.uid).update({
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      }

      // Get ID token
      _token = await firebaseUser.getIdToken();

      // Create User object
      final user = User(
        id: firebaseUser.uid,
        name: userData['name'] ?? firebaseUser.displayName ?? 'User',
        email: firebaseUser.email ?? email,
        profileImage: userData['profileImage'],
        isGuest: false,
        isVerified: true,
        createdAt: userData['createdAt']?.toDate() ?? DateTime.now(),
      );

      _currentUser = user;
      _isGuest = false;

      await _saveAuthData();
      notifyListeners();

      return AuthResponse(
        success: true,
        message: 'Login successful',
        token: _token,
        user: user,
      );

    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid email or password.';
          break;
        default:
          errorMessage = e.message ?? 'Login failed';
      }

      if (kDebugMode) {
        print('Firebase Auth Error: ${e.code} - ${e.message}');
      }

      return AuthResponse(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Login error: $e');
      }
      return AuthResponse(
        success: false,
        message: 'Login failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Guest login - no Firebase authentication
  Future<AuthResponse> loginAsGuest() async {
    _setLoading(true);

    try {
      final guestUser = User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Guest User',
        email: 'guest@example.com',
        isGuest: true,
        createdAt: DateTime.now(),
      );

      _currentUser = guestUser;
      _token = null;
      _refreshToken = null;
      _isGuest = true;

      await _saveAuthData();
      notifyListeners();

      return AuthResponse(
        success: true,
        message: 'Guest login successful',
        user: guestUser,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Guest login failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Send OTP for forgot password (Firebase Password Reset)
  Future<OtpResponse> sendOtp(String email) async {
    _setLoading(true);

    try {
      // Send password reset email via Firebase
      await _firebaseAuth.sendPasswordResetEmail(email: email);

      return OtpResponse(
        success: true,
        message: 'Password reset email sent to $email',
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address.';
          break;
        default:
          errorMessage = e.message ?? 'Failed to send reset email';
      }

      return OtpResponse(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      return OtpResponse(
        success: false,
        message: 'Failed to send reset email: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Verify OTP (Mock for now - Firebase doesn't have OTP verification)
  Future<OtpResponse> verifyOtp(String email, String otp) async {
    _setLoading(true);

    try {
      await Future.delayed(const Duration(seconds: 1));

      // For testing: accept "123456" as valid OTP
      if (otp == '123456') {
        return OtpResponse(
          success: true,
          message: 'OTP verified successfully',
        );
      } else {
        return OtpResponse(
          success: false,
          message: 'Invalid OTP. Use 123456 for testing.',
        );
      }
    } catch (e) {
      return OtpResponse(
        success: false,
        message: 'OTP verification failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Reset password (handled by Firebase email link)
  Future<AuthResponse> resetPassword(String email, String otp, String newPassword) async {
    _setLoading(true);

    try {
      // Firebase handles password reset via email link
      // This is just a placeholder
      await Future.delayed(const Duration(seconds: 1));

      return AuthResponse(
        success: true,
        message: 'Password reset successful. Please check your email.',
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Password reset failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Google Sign In (Mock - requires google_sign_in package)
  Future<AuthResponse> signInWithGoogle(String googleToken) async {
    _setLoading(true);

    try {
      // TODO: Implement actual Google Sign In
      // You need to add google_sign_in package and implement properly

      await Future.delayed(const Duration(seconds: 2));

      final mockUser = User(
        id: 'google_user_${DateTime.now().millisecondsSinceEpoch}',
        name: 'Google User',
        email: 'googleuser@gmail.com',
        isGuest: false,
        createdAt: DateTime.now(),
      );

      _token = 'google_token_${DateTime.now().millisecondsSinceEpoch}';
      _refreshToken = 'google_refresh_token_${DateTime.now().millisecondsSinceEpoch}';
      _currentUser = mockUser;
      _isGuest = false;

      await _saveAuthData();
      notifyListeners();

      return AuthResponse(
        success: true,
        message: 'Google sign in successful',
        token: _token,
        refreshToken: _refreshToken,
        user: mockUser,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Google sign in failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      // Sign out from Firebase if not guest
      if (!_isGuest && _firebaseAuth.currentUser != null) {
        await _firebaseAuth.signOut();
      }

      // Clear local data
      _currentUser = null;
      _token = null;
      _refreshToken = null;
      _isGuest = false;

      await _clearAuthData();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Logout error: $e');
      }
    }
  }

  // Update user profile
  Future<AuthResponse> updateProfile(String name, String email, String? profileImage) async {
    if (_isGuest) {
      return AuthResponse(
        success: false,
        message: 'Guest users cannot update profile',
      );
    }

    _setLoading(true);

    try {
      final firebaseUser = _firebaseAuth.currentUser;

      if (firebaseUser == null) {
        throw Exception('No user logged in');
      }

      // Update display name in Firebase Auth
      await firebaseUser.updateDisplayName(name);

      // Update data in Firestore
      await _firestore.collection('users').doc(firebaseUser.uid).update({
        'name': name,
        'email': email,
        'profileImage': profileImage,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local user object
      _currentUser = User(
        id: _currentUser!.id,
        name: name,
        email: email,
        profileImage: profileImage,
        isGuest: false,
        isVerified: _currentUser!.isVerified,
        createdAt: _currentUser!.createdAt,
        updatedAt: DateTime.now(),
      );

      await _saveAuthData();
      notifyListeners();

      return AuthResponse(
        success: true,
        message: 'Profile updated successfully',
        user: _currentUser,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Profile update failed: $e',
      );
    } finally {
      _setLoading(false);
    }
  }

  // Check if user is authenticated
  Future<bool> checkAuthStatus() async {
    if (_isGuest) {
      return true;
    }

    final firebaseUser = _firebaseAuth.currentUser;
    return firebaseUser != null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}