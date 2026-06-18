import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
    this.role = 'farmer',
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
  /// User role: 'farmer' | 'researcher' | 'admin'
  final String role;
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
    String? role,
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
      role: role ?? this.role,
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
      role: json['role']?.toString() ?? 'farmer',
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
      'role': role,
      'profile_completed': profileCompleted,
    };
  }
}

class UserProvider extends ChangeNotifier with WidgetsBindingObserver {
  UserProvider({ApiClient? apiClient, SessionStorage? sessionStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _sessionStorage = sessionStorage ?? SessionStorage() {
    hydrate();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-register the FCM token on app resume so a token that rotated while
  /// the app was in the background is always up to date in the backend.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _user.isLoggedIn) {
      unawaited(_registerFcmToken());
    }
  }

  final ApiClient _apiClient;
  final SessionStorage _sessionStorage;

  UserData _user = const UserData();
  bool _isLoading = false;
  bool _isHydrated = false;
  String? _errorMessage;
  String? _pendingPhone;
  String? _pendingEmail;
  /// Non-null only in mock/dev mode when Gmail SMTP is not configured.
  /// Contains the OTP code so it can be displayed directly in the UI.
  String? devEmailOtp;
  DateTime? _registeredAt;

  static const int trialDays = 7;

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
  String? get pendingEmail => _pendingEmail;
  String? get fullName => _user.fullName.isNotEmpty ? _user.fullName : null;
  String? get phone => _user.phone.isNotEmpty ? _user.phone : null;
  String? get email => _user.email.isNotEmpty ? _user.email : null;
  String? get country => _user.country.isNotEmpty ? _user.country : null;
  String? get photoPath => _user.profilePhotoPath;
  String get plan => _user.plan;
  String get role => _user.role;

  /// Whether the logged-in user has admin privileges.
  bool get isAdmin => _user.role == 'admin';

  /// Whether the user has an active paid subscription.
  bool get isSubscribed => _user.plan != 'free';

  /// Days remaining in the free trial (0 if expired or subscribed).
  int get trialDaysLeft {
    if (isSubscribed) return 0;
    if (_registeredAt == null) return trialDays;
    final elapsed = DateTime.now().difference(_registeredAt!).inDays;
    return (trialDays - elapsed).clamp(0, trialDays);
  }

  /// True when the 7-day trial has ended and the user is not subscribed.
  bool get isTrialExpired => !isSubscribed && trialDaysLeft == 0;

  Future<void> hydrate() async {
    _setLoading(true);
    Map<String, dynamic>? cachedUser;
    try {
      final token = await _sessionStorage.readToken();
      if (token == null || token.isEmpty) {
        _user = const UserData();
        return;
      }

      // Load trial start date (null = never logged in before, treat as today)
      _registeredAt = await _sessionStorage.readRegisteredAt();

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

  /// Email signup — stash profile data, send OTP (with name so backend can
  /// pre-check for duplicate email before actually sending the code).
  Future<bool> signupWithEmail({
    required String fullName,
    required String country,
    required String email,
  }) async {
    _pendingSignupName = fullName;
    _pendingSignupCountry = country;
    _setLoading(true);
    try {
      final res = await _apiClient.post('/api/auth/send-email-otp', body: {
        'email': email,
        'name': fullName, // tells backend this is a signup — enables pre-check
      });
      _pendingEmail = email;
      // Dev mode: backend returns the code directly when Gmail isn't configured.
      devEmailOtp = (res['data'] as Map<String, dynamic>?)?['dev_code']?.toString();
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Email login — send a 6-digit OTP to the given email via Gmail SMTP.
  Future<bool> sendEmailOtp(String email) async {
    _setLoading(true);
    try {
      final res = await _apiClient.post('/api/auth/send-email-otp', body: {'email': email});
      _pendingEmail = email;
      // Dev mode: backend returns the code directly when Gmail isn't configured.
      devEmailOtp = (res['data'] as Map<String, dynamic>?)?['dev_code']?.toString();
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify the email OTP. Works for both login and signup flows.
  Future<bool> verifyEmailOtp(String otp, {String? email}) async {
    _setLoading(true);
    try {
      final resolvedEmail = email ?? _pendingEmail ?? '';
      final body = <String, dynamic>{
        'email': resolvedEmail,
        'code': otp,
        ...?(_pendingSignupName == null ? null : {'name': _pendingSignupName!}),
        ...?(_pendingSignupCountry == null ? null : {'country': _pendingSignupCountry!}),
      };

      final response = await _apiClient.post('/api/auth/verify-email-otp', body: body);
      final data = response['data'] as Map<String, dynamic>;
      final token = data['token']?.toString() ?? '';
      final userJson = data['user'] as Map<String, dynamic>;
      await _sessionStorage.saveToken(token);
      await _sessionStorage.saveUser(userJson);

      await _sessionStorage.saveRegisteredAtIfAbsent(DateTime.now());
      _registeredAt ??= await _sessionStorage.readRegisteredAt();

      _user = UserData.fromJson(userJson);
      _pendingEmail = _user.email;
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

      // Anchor the trial clock to the very first login
      await _sessionStorage.saveRegisteredAtIfAbsent(DateTime.now());
      _registeredAt ??= await _sessionStorage.readRegisteredAt();

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

  /// Activates a paid plan by calling the backend, then updates local state.
  /// Falls back to a local-only update when the backend is unreachable so
  /// the UI is never left in a broken state after a simulated payment.
  Future<bool> subscribe(String planKey) async {
    _setLoading(true);
    try {
      final response = await _apiClient.post(
        '/api/subscriptions/subscribe',
        auth: true,
        body: {'plan': planKey},
      );
      final userJson =
          (response['data'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      await _sessionStorage.saveUser(userJson);
      _errorMessage = null;
      return true;
    } catch (_) {
      // Backend not available — update plan locally so the UI reflects the
      // subscription immediately (matches demo / offline-first behaviour).
      _user = _user.copyWith(plan: planKey);
      await _sessionStorage.saveUser(_user.toJson());
      _errorMessage = null;
      return true;
    } finally {
      _setLoading(false);
    }
  }

  // ── Contact linking ──────────────────────────────────────────────────────────

  /// Send OTP to a phone number the user wants to link to their account.
  Future<bool> sendLinkPhoneOtp(String phone) async {
    _setLoading(true);
    try {
      await _apiClient.post('/api/auth/link-phone', body: {'phone': phone}, auth: true);
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

  /// Verify OTP and attach the phone to the current account.
  Future<bool> verifyLinkPhone(String otp) async {
    _setLoading(true);
    try {
      final phone = _pendingPhone ?? '';
      final response = await _apiClient.post(
        '/api/auth/verify-link-phone',
        body: {'phone': phone, 'code': otp},
        auth: true,
      );
      final userJson = (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      await _sessionStorage.saveUser(userJson);
      _pendingPhone = null;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Send OTP to an email the user wants to link to their account.
  Future<bool> sendLinkEmailOtp(String email) async {
    _setLoading(true);
    try {
      await _apiClient.post('/api/auth/link-email', body: {'email': email}, auth: true);
      _pendingEmail = email;
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Verify OTP and attach the email to the current account.
  Future<bool> verifyLinkEmail(String otp) async {
    _setLoading(true);
    try {
      final email = _pendingEmail ?? '';
      final response = await _apiClient.post(
        '/api/auth/verify-link-email',
        body: {'email': email, 'code': otp},
        auth: true,
      );
      final userJson = (response['data'] as Map<String, dynamic>)['user'] as Map<String, dynamic>;
      _user = UserData.fromJson(userJson);
      await _sessionStorage.saveUser(userJson);
      _pendingEmail = null;
      _errorMessage = null;
      notifyListeners();
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
    _pendingEmail = null;
    _user = const UserData();
    notifyListeners();
  }

  /// Called when the user navigates back from the OTP screen to re-choose a method.
  void clearPendingContact() {
    _pendingPhone = null;
    _pendingEmail = null;
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
    // Wire the refresh callback every time so a rotated token is always
    // re-sent even if this method is called multiple times (idempotent).
    FcmService.onTokenRefresh = (newToken) async {
      if (!_user.isLoggedIn) return;
      try {
        await _apiClient.post(
          '/api/notifications/device-token',
          body: {'token': newToken},
          auth: true,
        );
        debugPrint('[FCM] Refreshed token registered with backend');
      } catch (e) {
        debugPrint('[FCM] Refreshed token registration failed: $e');
      }
    };

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