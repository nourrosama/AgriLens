import 'package:flutter/material.dart';

/// User profile data model
class UserData {
  String fullName;
  String phone;
  String email;
  String country;
  String? profilePhotoPath;
  bool isLoggedIn;

  UserData({
    this.fullName = '',
    this.phone = '',
    this.email = '',
    this.country = '',
    this.profilePhotoPath,
    this.isLoggedIn = false,
  });
}

/// Provider that manages user profile and auth state.
/// Ready to connect to backend — see TODO comments for API integration points.
class UserProvider extends ChangeNotifier {
  UserData _user = UserData(
    fullName: 'Ahmed Hassan',
    phone: '+20 123 456 7890',
    email: 'ahmed.hassan@email.com',
    country: 'egypt',
    isLoggedIn: true,
  );

  UserData get user => _user;
  bool get isLoggedIn => _user.isLoggedIn;
  String? get fullName => _user.fullName.isNotEmpty ? _user.fullName : null;
  String? get phone => _user.phone.isNotEmpty ? _user.phone : null;
  String? get email => _user.email.isNotEmpty ? _user.email : null;
  String? get country => _user.country.isNotEmpty ? _user.country : null;
  String? get photoPath => _user.profilePhotoPath;

  /// TODO: Replace with API call to POST /api/auth/register
  void register({
    required String fullName,
    required String country,
    String? profilePhotoPath,
  }) {
    _user = UserData(
      fullName: fullName,
      country: country,
      profilePhotoPath: profilePhotoPath,
      isLoggedIn: false,
    );
    notifyListeners();
  }

  /// TODO: Replace with API call to POST /api/auth/login
  void login(String phone) {
    _user.phone = phone;
    notifyListeners();
  }

  /// TODO: Replace with API call to POST /api/auth/verify-otp
  void verifyOtp(String otp) {
    _user.isLoggedIn = true;
    notifyListeners();
  }

  void updateProfile({String? fullName, String? email, String? country, String? photoPath}) {
    if (fullName != null) _user.fullName = fullName;
    if (email != null) _user.email = email;
    if (country != null) _user.country = country;
    if (photoPath != null) _user.profilePhotoPath = photoPath;
    notifyListeners();
  }

  void logout() {
    _user = UserData();
    notifyListeners();
  }
}
