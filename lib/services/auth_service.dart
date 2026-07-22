import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AuthService {
  static const String _activeUserBoxName = 'active_user';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Box> _getActiveUserBox() async {
    return Hive.openBox(_activeUserBoxName);
  }

  Future<Box> getUserDataBox(String dataKey) async {
    final uid = await getActiveUserId();

    if (uid == null || uid.isEmpty) {
      throw Exception('No active user');
    }

    return Hive.openBox('${dataKey}_$uid');
  }

  Future<void> _ensureUserDataBoxes(String uid) async {
    final dataKeys = [
      'profile',
      'attendance',
      'timetable',
      'sessions',
      'completedTasks',
      'points',
      'settings',
      'crop_plots',
    ];

    for (final key in dataKeys) {
      await Hive.openBox('${key}_$uid');
    }
  }

  /// REGISTER
  Future<void> register(
    String fullName,
    String email,
    String password,
    String confirmPassword,
  ) async {
    if (fullName.trim().isEmpty) {
      throw Exception('Full name is required');
    }

    if (email.trim().isEmpty) {
      throw Exception('Email is required');
    }

    if (password.isEmpty) {
      throw Exception('Password is required');
    }

    if (password != confirmPassword) {
      throw Exception('Passwords do not match');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': fullName.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final activeUserBox = await _getActiveUserBox();
      await activeUserBox.put('current_user_id', uid);

      await _ensureUserDataBoxes(uid);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw Exception('This email is already registered.');

        case 'invalid-email':
          throw Exception('Please enter a valid email.');

        case 'weak-password':
          throw Exception('Password must be at least 6 characters.');

        default:
          throw Exception(e.message ?? 'Registration failed.');
      }
    }
  }

  /// LOGIN
  Future<void> login(
    String email,
    String password,
  ) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      final userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw Exception('User profile not found.');
      }

      final activeUserBox = await _getActiveUserBox();
      await activeUserBox.put('current_user_id', uid);

      await _ensureUserDataBoxes(uid);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw Exception('Please enter a valid email.');

        case 'user-not-found':
          throw Exception('No account found with this email.');

        case 'wrong-password':
          throw Exception('Incorrect password.');

        case 'invalid-credential':
          throw Exception('Invalid email or password.');

        default:
          throw Exception(e.message ?? 'Login failed.');
      }
    }
  }

  /// CURRENT USER
  Future<String?> getActiveUserId() async {
    final currentUser = _auth.currentUser;

    if (currentUser != null) {
      return currentUser.uid;
    }

    final box = await _getActiveUserBox();
    return box.get('current_user_id') as String?;
  }

  /// LOGOUT
  Future<void> logout() async {
    await _auth.signOut();

    final box = await _getActiveUserBox();
    await box.clear();
  }
}