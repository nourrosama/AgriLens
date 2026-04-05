import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'push_notifications_service.dart';
import 'session_storage.dart';

class UserData {
  const UserData({
    this.id = '',
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.country = '',
    this.profilePhotoPath,
    this.language = 'en',
    this.plan = 'free',
    this.profileCompleted = false,
    this.isLoggedIn = false,
  });

  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String country;
  final String? profilePhotoPath;
  final String language;
  final String plan;
  final bool profileCompleted;
  final bool isLoggedIn;

  UserData copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? country,
    String? profilePhotoPath,
    String? language,
    String? plan,
    bool? profileCompleted,
    bool? isLoggedIn,
  }) {
    return UserData(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      country: country ?? this.country,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      language: language ?? this.language,
      plan: plan ?? this.plan,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id']?.toString() ?? '',
      fullName: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      country: json['country']?.toString() ?? '',
      profilePhotoPath: json['photo_url']?.toString(),
      language: json['language']?.toString() ?? 'en',
      plan: json['plan']?.toString() ?? 'free',
      profileCompleted: json['profile_completed'] == true,
      isLoggedIn: true,
    );
  }
}

class UserProvider extends ChangeNotifier {
  UserProvider({ApiClient? apiClient, SessionStorage? sessionStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _sessionStorage = sessionStorage ?? SessionStorage() {
    hydrate();
  }

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  UserData _user = const UserData();
  bool _isLoading = false;
  bool _isHydrated = false;
  String? _errorMessage;
  String? _pendingPhone;

  UserData get user => _user;
  bool get isLoggedIn => _user.isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isHydrated => _isHydrated;
  bool get profileCompleted => _user.profileCompleted;
  String? get errorMessage => _errorMessage;
  String? get pendingPhone => _pendingPhone;
  String? get fullName => _user.fullName.isNotEmpty ? _user.fullName : null;
  String? get phone => _user.phone.isNotEmpty ? _user.phone : null;
  String? get email => _user.email.isNotEmpty ? _user.email : null;
  String? get country => _user.country.isNotEmpty ? _user.country : null;
  String? get photoPath => _user.profilePhotoPath;
  String get plan => _user.plan;

  Future<void> hydrate() async {
    _setLoading(true);
    try {
      final token = await _sessionStorage.readToken();
      if (token == null || token.isEmpty) {
        _user = const UserData();
        return;
      }
      final response = await _apiClient.get('/api/auth/me', auth: true);
      final userJson =
          (response['data'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      await PushNotificationsService.instance.registerCurrentDevice();
    } catch (_) {
      await _sessionStorage.clearToken();
      _user = const UserData();
    } finally {
      _isHydrated = true;
      _setLoading(false);
    }
  }

  Future<bool> sendOtp(String phone) async {
    _setLoading(true);
    try {
      // On web, use test login endpoint for development
      if (kIsWeb) {
        final response = await _apiClient.post(
          '/api/auth/send-otp',
          body: {'phone': phone},
        );
        final data = response['data'] as Map<String, dynamic>;
        final token = data['token']?.toString() ?? '';
        final userId = data['user_id']?.toString() ?? '';
        
        await _sessionStorage.saveToken(token);
        _user = UserData(
          id: userId,
          phone: phone,
          fullName: 'Test User',
          isLoggedIn: true,
        );
        _pendingPhone = phone;
        _errorMessage = null;
        
        // Skip push notifications on web
        return true;
      }
      
      // On mobile platforms, use actual OTP
      await _apiClient.post('/api/auth/send-otp', body: {'phone': phone});
      _pendingPhone = phone;
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyOtp(String otp, {String? phone}) async {
    _setLoading(true);
    try {
      // On web, use test verification endpoint
      final endpoint = '/api/auth/verify-otp';
      
      final response = await _apiClient.post(
        endpoint,
        body: {'phone': phone ?? _pendingPhone ?? _user.phone, 'code': otp},
      );
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userJson = data['user'] as Map<String, dynamic>;
      await _sessionStorage.saveToken(token);
      
      _user = UserData.fromJson(userJson);
      _pendingPhone = _user.phone;
      
      // Skip push notifications on web
      if (!kIsWeb) {
        await PushNotificationsService.instance.registerCurrentDevice();
      }
      
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String fullName,
    required String country,
    String? profilePhotoPath,
  }) async {
    return updateProfile(
      fullName: fullName,
      country: country,
      photoPath: profilePhotoPath,
      profileCompleted: true,
    );
  }

  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? country,
    String? photoPath,
    String? language,
    bool? profileCompleted,
  }) async {
    _setLoading(true);
    try {
      final response = await _apiClient.put(
        '/api/auth/me',
        auth: true,
        body: {
          ...?(fullName == null ? null : {'name': fullName}),
          ...?(email == null ? null : {'email': email}),
          ...?(country == null ? null : {'country': country}),
          ...?(photoPath == null ? null : {'photo_url': photoPath}),
          ...?(language == null ? null : {'language': language}),
          ...?(profileCompleted == null
              ? null
              : {'profile_completed': profileCompleted}),
        },
      );
      final userJson =
          (response['data'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await PushNotificationsService.instance.unregisterCurrentDevice();
    await _sessionStorage.clearToken();
    _pendingPhone = null;
    _user = const UserData();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
