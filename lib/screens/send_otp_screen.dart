import 'package:flutter/material.dart';

class SendOtpScreen extends StatefulWidget {
  const SendOtpScreen({super.key});

  @override
  State<SendOtpScreen> createState() => _SendOtpScreenState();
}

class _SendOtpScreenState extends State<SendOtpScreen> {
  final List<TextEditingController> _otpControllers =
  List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 30;
  bool _canResend = false;
  String? _userEmail;

  // Professional Olive Green Color Scheme
  final Color _primaryColor = const Color(0xFF556B2F); // Dark Olive Green
  final Color _accentColor = const Color(0xFF6B8E23); // Medium Olive Green
  final Color _dimLightOlive = const Color(0xFFE8EFDF); // Dim Light Olive Green

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    // Setup focus node listeners
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus && _otpControllers[i].text.isEmpty) {
          // Move focus to previous if current is empty and we're going backward
          if (i > 0) {
            _focusNodes[i - 1].requestFocus();
          }
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get email from arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null) {
      _userEmail = args as String;
    }
  }

  void _verifyOtp() async {
    String otp = _getOtpText();
    if (otp.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid 4-digit OTP'),
          backgroundColor: _primaryColor,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate OTP verification
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isLoading = false;
    });

    // Navigate to reset password screen
    _navigateToResetPassword();
  }

  void _navigateToResetPassword() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Success',
          style: TextStyle(color: _primaryColor),
        ),
        content: const Text(
          'Password reset successful! You can now login with your new password.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
            ),
            child: Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _resendTimer = 30;
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _resendTimer--;
        });
        if (_resendTimer > 0) {
          _startResendTimer();
        } else {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  void _resendOtp() {
    if (_canResend) {
      // Implement resend OTP logic here
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent successfully'),
          backgroundColor: _primaryColor,
        ),
      );
    }
  }

  String _getOtpText() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChange(String value, int index) {
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    // Auto verify when all boxes are filled
    if (_getOtpText().length == 4) {
      _verifyOtp();
    }
  }

  Widget _buildOtpBox(int index) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: SizedBox(
        width: 65,
        height: 65,
        child: TextFormField(
          controller: _otpControllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          decoration: InputDecoration(
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _primaryColor,
          ),
          onChanged: (value) => _onOtpChange(value, index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dimLightOlive, // Same dim light olive green background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Back Button
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
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: _primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Title
              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2F3E1F),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _userEmail != null
                    ? 'Enter 4-digit OTP sent to $_userEmail'
                    : 'Enter the 4-digit OTP sent to your email',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // OTP Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => _buildOtpBox(index)),
              ),
              const SizedBox(height: 30),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Didn't receive OTP?",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: _canResend ? _resendOtp : null,
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                      padding: const EdgeInsets.only(left: 8),
                    ),
                    child: Text(
                      _canResend ? 'Resend OTP' : 'Resend in $_resendTimer s',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Verify OTP Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                      : Text(
                    'Verify OTP',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Flexible space to push content to center
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}