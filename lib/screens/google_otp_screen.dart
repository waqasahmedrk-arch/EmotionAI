import 'package:flutter/material.dart';
import '../models/google_account.dart';

class GoogleOtpScreen extends StatefulWidget {
  const GoogleOtpScreen({super.key});

  @override
  State<GoogleOtpScreen> createState() => _GoogleOtpScreenState();
}

class _GoogleOtpScreenState extends State<GoogleOtpScreen> {
  final List<TextEditingController> _otpControllers =
  List.generate(4, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  bool _isLoading = false;
  int _resendTimer = 30;
  bool _canResend = false;
  GoogleAccount? _selectedAccount;
  bool _isDisposed = false;
  bool _isNewAccount = false;
  bool _otpVerified = false;

  // Professional Olive Green Color Scheme
  final Color _primaryColor = const Color(0xFF556B2F); // Dark Olive Green
  final Color _accentColor = const Color(0xFF6B8E23); // Medium Olive Green
  final Color _dimLightOlive = const Color(0xFFE8EFDF); // Dim Light Olive Green

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    _setupFocusListeners();
    _autoFillDemoOtp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get selected account from arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map) {
      _selectedAccount = args['account'] as GoogleAccount;
      _isNewAccount = args['isNewAccount'] as bool? ?? false;
    }
  }

  void _autoFillDemoOtp() {
    // Auto-fill demo OTP after a short delay for testing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_otpVerified) {
        _fillDemoOtp();
      }
    });
  }

  void _fillDemoOtp() {
    // Fill with demo OTP: 1234
    if (_isDisposed) return;

    for (int i = 0; i < 4; i++) {
      _otpControllers[i].text = (i + 1).toString();
    }

    // Move focus away from OTP fields
    _focusNodes[3].unfocus();
  }

  void _setupFocusListeners() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_isDisposed) return;
        if (!_focusNodes[i].hasFocus && _otpControllers[i].text.isEmpty) {
          if (i > 0) {
            _focusNodes[i - 1].requestFocus();
          }
        }
      });
    }
  }

  void _verifyOtp() async {
    if (_isLoading || _otpVerified) return;

    String otp = _getOtpText();
    if (otp.length != 4) {
      if (!mounted) return;
      _showErrorSnackBar('Please enter a valid 4-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate OTP verification API call
    await Future.delayed(const Duration(seconds: 2));

    if (_isDisposed) return;

    setState(() {
      _isLoading = false;
    });

    // Check if OTP is correct (in real app, verify with backend)
    if (otp == '1234') { // Mock correct OTP
      _handleSuccessfulVerification();
    } else {
      _handleFailedVerification();
    }
  }

  void _handleSuccessfulVerification() {
    setState(() {
      _otpVerified = true;
    });
    _showSuccessDialog();
  }

  void _handleFailedVerification() {
    if (!mounted) return;

    // Clear OTP fields on failure
    for (var controller in _otpControllers) {
      controller.clear();
    }
    // Refocus first field
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }

    _showErrorSnackBar('Invalid OTP. Please try again.');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    if (!mounted) return;

    final verifiedAccount = GoogleAccount(
      name: _selectedAccount!.name,
      email: _selectedAccount!.email,
      avatar: _selectedAccount!.avatar,
      isVerified: true,
      addedDate: DateTime.now(),
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Icon(
              Icons.verified,
              color: _primaryColor,
              size: 48,
            ),
            const SizedBox(height: 8),
            Text(
              _isNewAccount ? 'Account Added!' : 'Verification Successful!',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNewAccount
                  ? 'Your Google account has been added successfully:'
                  : 'Google account verified successfully:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _primaryColor.withOpacity(0.2),
                    radius: 20,
                    child: Text(
                      verifiedAccount.avatar,
                      style: TextStyle(
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          verifiedAccount.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          verifiedAccount.email,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isNewAccount
                  ? 'You can now use this account to sign in to EEG Prediction.'
                  : 'You can now access EEG Prediction features.',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (!mounted) return;

              if (_isNewAccount) {
                // Return the verified account to the previous screen
                Navigator.pop(context, verifiedAccount);
              } else {
                // Go to home screen
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              _isNewAccount ? 'View Accounts' : 'Continue to App',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startResendTimer() {
    if (_isDisposed) return;

    setState(() {
      _canResend = false;
      _resendTimer = 30;
    });

    _updateTimer();
  }

  void _updateTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_isDisposed) return;
      if (!mounted) return;

      setState(() {
        _resendTimer--;
      });

      if (_resendTimer > 0) {
        _updateTimer();
      } else {
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  void _resendOtp() {
    if (_canResend && !_isDisposed && !_otpVerified) {
      _startResendTimer();
      if (!mounted) return;

      // Clear previous OTP
      for (var controller in _otpControllers) {
        controller.clear();
      }
      // Refocus first field
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New OTP sent to ${_selectedAccount?.email}'),
          backgroundColor: _primaryColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Auto-fill demo OTP again
      _autoFillDemoOtp();
    }
  }

  String _getOtpText() {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChange(String value, int index) {
    if (_isDisposed || _otpVerified) return;

    // Allow only numeric input
    if (value.isNotEmpty && !RegExp(r'^[0-9]$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

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

  void _clearOtp() {
    if (_otpVerified) return;

    for (var controller in _otpControllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
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
          enabled: !_otpVerified && !_isLoading,
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
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _otpVerified ? Colors.green : Colors.grey[300]!,
                width: _otpVerified ? 2 : 1,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.green,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: _otpVerified
                ? Colors.green.withOpacity(0.1)
                : Colors.white,
            contentPadding: EdgeInsets.zero,
          ),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: _otpVerified ? Colors.green : _primaryColor,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () {
            if (_isNewAccount) {
              // Show confirmation dialog when going back from new account flow
              _showExitConfirmation();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _isNewAccount ? 'Verify New Account' : 'Verify Account',
          style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account Info
              if (_selectedAccount != null) ...[
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: _primaryColor.withOpacity(0.1),
                            radius: 40,
                            child: Text(
                              _selectedAccount!.avatar,
                              style: TextStyle(
                                fontSize: 24,
                                color: _primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_otpVerified)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedAccount!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedAccount!.email,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_isNewAccount) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'New Account',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],

              // Verification Status
              if (_otpVerified) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Account successfully verified!',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Instructions
              const Text(
                'Verification Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isNewAccount
                    ? 'We\'ve sent a 4-digit OTP to verify your new account:'
                    : 'For security, we\'ve sent a 4-digit OTP to your email:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                _selectedAccount?.email ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: _primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // OTP Boxes
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) => _buildOtpBox(index)),
                  ),
                  if (!_otpVerified) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _clearOtp,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                      child: const Text('Clear OTP'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 30),

              // Resend OTP Section
              if (!_otpVerified) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive OTP?",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    TextButton(
                      onPressed: _canResend ? _resendOtp : null,
                      style: TextButton.styleFrom(
                        foregroundColor: _primaryColor,
                      ),
                      child: Text(
                        _canResend ? 'Resend OTP' : 'Resend in $_resendTimer s',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],

              // Verify OTP Button
              if (!_otpVerified) ...[
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
                      _isNewAccount ? 'Verify and Add Account' : 'Verify OTP',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              // Demo OTP Hint
              if (!_otpVerified) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.amber[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demo OTP: 1234',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _fillDemoOtp,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber[800],
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                        ),
                        child: const Text(
                          'Tap to auto-fill demo OTP',
                          style: TextStyle(
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Add extra space at the bottom for safety
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit without adding?'),
        content: const Text('Are you sure you want to go back? Your account details will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;

    // Dispose focus nodes first
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }

    // Then dispose controllers
    for (var controller in _otpControllers) {
      controller.dispose();
    }

    super.dispose();
  }
}