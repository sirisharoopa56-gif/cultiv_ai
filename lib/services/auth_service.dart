import 'package:hive_flutter/hive_flutter.dart';

class AuthUser {
  final String userId;
  final String username;
  final String password;
  final String fullName;

  AuthUser({
    required this.userId,
    required this.username,
    required this.password,
    required this.fullName,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'username': username,
        'password': password,
        'fullName': fullName,
      };

  factory AuthUser.fromJson(Map<dynamic, dynamic> json) => AuthUser(
        userId: json['userId'] as String,
        username: json['username'] as String,
        password: json['password'] as String,
        fullName: (json['fullName'] as String?) ?? '',
      );
}

class AuthService {
  static const String _usersBoxName = 'auth_users';
  static const String _activeUserBoxName = 'active_user';

  Future<Box> _getUsersBox() async => Hive.openBox(_usersBoxName);

  Future<Box> _getActiveUserBox() async => Hive.openBox(_activeUserBoxName);

  Future<Box> getUserDataBox(String dataKey) async {
    final userId = await getActiveUserId();
    if (userId == null || userId.isEmpty) {
      throw Exception('No active user');
    }

    return Hive.openBox('${dataKey}_$userId');
  }

  Future<void> _ensureUserDataBoxes(String userId) async {
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

    for (final dataKey in dataKeys) {
      await Hive.openBox('${dataKey}_$userId');
    }
  }

  Future<String> register(
    String fullName,
    String username,
    String password,
    String confirmPassword,
  ) async {
    final trimmedName = fullName.trim();
    final normalizedUsername = username.trim().toLowerCase();

    if (trimmedName.isEmpty) {
      throw Exception('Full name is required');
    }

    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required');
    }

    if (password != confirmPassword) {
      throw Exception('Passwords do not match.');
    }

    final box = await _getUsersBox();
    if (box.containsKey(normalizedUsername)) {
      throw Exception('Username already exists. Please choose another username.');
    }

    final user = AuthUser(
      userId: DateTime.now().microsecondsSinceEpoch.toString(),
      username: username.trim(),
      password: password,
      fullName: trimmedName,
    );

    await box.put(normalizedUsername, user.toJson());
    await _ensureUserDataBoxes(user.userId);

    return user.userId;
  }

  Future<String> login(String username, String password) async {
    final normalizedUsername = username.trim().toLowerCase();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required');
    }

    final box = await _getUsersBox();
    final data = box.get(normalizedUsername);
    if (data == null) {
      throw Exception('Account not found. Please create an account first.');
    }

    final user = AuthUser.fromJson(data);
    if (user.password != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    final activeUserBox = await _getActiveUserBox();
    await activeUserBox.put('current_user_id', user.userId);
    await _ensureUserDataBoxes(user.userId);

    return user.userId;
  }

  Future<String?> getActiveUserId() async {
    final box = await _getActiveUserBox();
    return box.get('current_user_id') as String?;
  }

  Future<void> logout() async {
    final box = await _getActiveUserBox();
    await box.delete('current_user_id');
  }
}
