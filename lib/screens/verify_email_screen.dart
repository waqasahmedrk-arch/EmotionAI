import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'dart:async';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isVerifying = false;
  bool _isResending = false;
  int _resendTimer = 60;
  bool _canResend = false;
  Timer? _timer;
  Timer? _checkTimer;
  String? _userEmail;

  final Color _primaryColor = const Color(0xFF556B2F);
  final Color _dimLightOlive = const Color(0xFFE8EFDF);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _startVerificationCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      _userEmail = args as String;
    }
  }

  void _startVerificationCheck() {
    // Check email verification status every 3 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        final isVerified = await authService.checkEmailVerified();

        if (isVerified) {
          timer.cancel();
          _onVerificationSuccess();
        }
      } catch (e) {
        // Continue checking even if there's an error
        print('Verification check error: $e');
      }
    });
  }

  void _onVerificationSuccess() {
    if (!mounted) return;

    // Cancel timers
    _checkTimer?.cancel();
    _timer?.cancel();

    Navigator.pushReplacementNamed(context, '/login');

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email verified successfully! Please login to continue.'),
            backgroundColor: _primaryColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _resendTimer--;
      });

      if (_resendTimer <= 0) {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.resendVerificationEmail();

      if (!mounted) return;

      _startResendTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Verification email sent! Please check your inbox.'),
          backgroundColor: _primaryColor,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend email: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  void _checkVerificationManually() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Force reload the current user before checking
      await authService.reloadCurrentUser();

      final isVerified = await authService.checkEmailVerified();

      if (!mounted) return;

      if (isVerified) {
        _onVerificationSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Email not verified yet. Please check your inbox and click the verification link.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification check failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dimLightOlive,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header with back button
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: Icon(Icons.arrow_back, color: _primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Email icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 50,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 30),

              // Title
              Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                _userEmail != null
                    ? 'We sent a verification link to\n$_userEmail'
                    : 'We sent a verification link to your email',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'Click the link in the email to verify your account',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Check Verification Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _checkVerificationManually,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                        : const Text(
                      'I\'ve Verified My Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Resend Email
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive the email?",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _canResend && !_isResending
                        ? _resendVerificationEmail
                        : null,
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.only(left: 8),
                    ),
                    child: _isResending
                        ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(_primaryColor),
                      ),
                    )
                        : Text(
                      _canResend
                          ? 'Resend Email'
                          : 'Resend in $_resendTimer s',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _canResend ? _primaryColor : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Check your spam folder if you don\'t see the email in your inbox',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _checkTimer?.cancel();
    super.dispose();
  }
}