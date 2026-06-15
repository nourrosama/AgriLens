import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'session_storage.dart';
import 'fcm_service.dart';

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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': fullName,
      'phone': phone,
      'email': email,
      'country': country,
      'photo_url': profilePhotoPath ?? '',
      'language': language,
      'plan': plan,
      'profile_completed': profileCompleted,
    };
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
  // Signup flow: stored here so verifyOtp can include them in the request body
  String? _pendingSignupName;
  String? _pendingSignupCountry;

  UserData get user => _user;
  String get userId => _user.id;
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
    Map<String, dynamic>? cachedUser;
    try {
      final token = await _sessionStorage.readToken();
      if (token == null || token.isEmpty) {
        _user = const UserData();
        return;
      }

      cachedUser = await _sessionStorage.readUser();
      if (cachedUser != null) {
        _user = UserData.fromJson(cachedUser);
        notifyListeners();
      }

      final response = await _apiClient.get('/api/auth/me', auth: true);
      final userJson =
          (response['data'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      await _sessionStorage.saveUser(userJson);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _sessionStorage.clearSession();
        _user = const UserData();
      } else if (cachedUser == null) {
        _user = const UserData();
      }
    } catch (_) {
      if (cachedUser == null) {
        _user = const UserData();
      }
    } finally {
      _isHydrated = true;
      _setLoading(false);
    }
  }

  /// Registration flow — collect profile first, then send OTP.
  /// Calls POST /api/auth/register (phone must be new).
  Future<bool> signup({
    required String fullName,
    required String country,
    required String phone,
    String email = '',
  }) async {
    _setLoading(true);
    try {
      await _apiClient.post('/api/auth/register', body: {
        'name': fullName,
        'country': country,
        'phone': phone,
        if (email.isNotEmpty) 'email': email,
      });
      _pendingPhone = phone;
      _pendingSignupName = fullName;
      _pendingSignupCountry = country;
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
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
      final resolvedPhone = phone ?? _pendingPhone ?? _user.phone;
      final body = <String, dynamic>{
        'phone': resolvedPhone,
        'code': otp,
        // Include signup profile if this is the registration flow.
        // The backend uses their presence to decide signup vs login.
        ...?(_pendingSignupName == null ? null : {'name': _pendingSignupName!}),
        ...?(_pendingSignupCountry == null ? null : {'country': _pendingSignupCountry!}),
      };

      final response = await _apiClient.post('/api/auth/verify-otp', body: body);
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userJson = data['user'] as Map<String, dynamic>;
      await _sessionStorage.saveToken(token);
      await _sessionStorage.saveUser(userJson);

      _user = UserData.fromJson(userJson);
      _pendingPhone = _user.phone;
      // Clear signup state after successful verification
      _pendingSignupName = null;
      _pendingSignupCountry = null;

      unawaited(_registerFcmToken());

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
      final body = {
        ...?(fullName == null ? null : {'name': fullName}),
        ...?(email == null ? null : {'email': email}),
        ...?(country == null ? null : {'country': country}),
        ...?(language == null ? null : {'language': language}),
        ...?(profileCompleted == null
            ? null
            : {'profile_completed': profileCompleted}),
      };
      final photoFile = _localPhotoFile(photoPath);
      final textResponse = await _apiClient.put(
        '/api/auth/me',
        auth: true,
        body: {
          ...body,
          ...?(photoPath == null || photoFile != null
              ? null
              : {'photo_url': photoPath}),
        },
      );
      final textUserJson =
          (textResponse['data'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;
      _user = UserData.fromJson(textUserJson);
      await _sessionStorage.saveUser(textUserJson);

      if (photoFile != null) {
        final photoResponse = await _apiClient.multipart(
          '/api/auth/me',
          auth: true,
          file: photoFile,
          fieldName: 'photo',
          fields: const {},
          method: 'PUT',
        );
        final photoUserJson =
            (photoResponse['data'] as Map<String, dynamic>)['user']
                as Map<String, dynamic>;
        _user = UserData.fromJson(photoUserJson);
        await _sessionStorage.saveUser(photoUserJson);
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

  Future<void> logout() async {
    await _sessionStorage.clearSession();
    _pendingPhone = null;
    _user = const UserData();
    notifyListeners();
  }

  File? _localPhotoFile(String? photoPath) {
    if (photoPath == null || photoPath.isEmpty) {
      return null;
    }
    if (photoPath.startsWith('http://') ||
        photoPath.startsWith('https://') ||
        photoPath.startsWith('/uploads/')) {
      return null;
    }
    final file = File(photoPath);
    return file.existsSync() ? file : null;
  }

  Future<void> _registerFcmToken() async {
    final token = await FcmService.getToken();
    if (token == null) return;
    try {
      await _apiClient.post(
        '/api/notifications/device-token',
        body: {'token': token},
        auth: true,
      );
      debugPrint('[FCM] Device token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration failed (non-critical): $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
