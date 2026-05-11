import 'package:lost_found/models/user_model.dart';
class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final String? refreshToken;
  final User? user;
  final bool requiresVerification;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.refreshToken,
    this.user,
    this.requiresVerification = false,
  });
}

class OtpResponse {
  final bool success;
  final String message;
  final String? otp;

  OtpResponse({
    required this.success,
    required this.message,
    this.otp,
  });
}