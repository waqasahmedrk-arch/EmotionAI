import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Professional Olive Green Color Scheme
  final Color _primaryColor = const Color(0xFF556B2F);
  final Color _accentColor = const Color(0xFF6B8E23);
  final Color _dimLightOlive = const Color(0xFFE8EFDF);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login(AuthService authService) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Call login method
        final response = await authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (response.success) {
          // Navigate to home screen first
          Navigator.pushReplacementNamed(
            context,
            '/home',
            arguments: {
              'userName': response.user?.name ?? 'User',
              'isGuest': false,
            },
          );
        } else {
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response.message),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Login failed: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  void _continueWithGoogle(AuthService authService) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Mock Google token for now
      final response = await authService.signInWithGoogle('mock_google_token');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${response.user?.name ?? "User"}!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacementNamed(
          context,
          '/home',
          arguments: {
            'userName': response.user?.name ?? 'User',
            'isGuest': false,
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign in failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navigateToGuestLogin() {
    print('Navigating to guest login screen...');
    Navigator.pushNamed(context, '/guest-login').then((value) {
      print('Returned from guest login screen');
    }).catchError((error) {
      print('Error navigating to guest login: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        return Scaffold(
          backgroundColor: _dimLightOlive,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Custom App Logo
                    Container(
                      margin: const EdgeInsets.only(top: 20, bottom: 20),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.asset(
                            'assets/images/splash.png',
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.psychology,
                                size: 50,
                                color: _primaryColor,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // Welcome Text
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F3E1F),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Login to continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: TextStyle(color: _primaryColor, fontSize: 14),
                        prefixIcon: Icon(Icons.email, color: _primaryColor, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        labelStyle: TextStyle(color: _primaryColor, fontSize: 14),
                        prefixIcon: Icon(Icons.lock, color: _primaryColor, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: _primaryColor,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    // const SizedBox(height: 8),
                    //
                    // // Forgot Password
                    // Align(
                    //   alignment: Alignment.centerRight,
                    //   child: TextButton(
                    //     onPressed: () {
                    //       Navigator.pushNamed(context, '/forgot-password');
                    //     },
                    //     style: TextButton.styleFrom(
                    //       foregroundColor: _primaryColor,
                    //       padding: EdgeInsets.zero,
                    //       minimumSize: const Size(50, 30),
                    //     ),
                    //     child: Text(
                    //       'Forgot Password?',
                    //       style: TextStyle(
                    //         fontWeight: FontWeight.w600,
                    //         color: _primaryColor,
                    //         fontSize: 13,
                    //       ),
                    //     ),
                    //   ),
                    // ),
                    const SizedBox(height: 15),

                    // Login and Guest Login Buttons
                    Row(
                      children: [
                        // Login Button (Email/Password login)
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : () => _login(authService),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                disabledBackgroundColor: _primaryColor.withOpacity(0.6),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                                  : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Login as Guest Button
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _isLoading ? null : _navigateToGuestLogin,
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _primaryColor,
                                side: BorderSide(color: _primaryColor, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                disabledBackgroundColor: Colors.white.withOpacity(0.6),
                              ),
                              child: Text(
                                'Login as Guest',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _primaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // // Divider
                    // Row(
                    //   children: [
                    //     Expanded(
                    //       child: Divider(color: Colors.grey[400]),
                    //     ),
                    //     Padding(
                    //       padding: const EdgeInsets.symmetric(horizontal: 10),
                    //       child: Text(
                    //         'Or continue with',
                    //         style: TextStyle(
                    //           color: Colors.grey[600],
                    //           fontSize: 11,
                    //         ),
                    //       ),
                    //     ),
                    //     Expanded(
                    //       child: Divider(color: Colors.grey[400]),
                    //     ),
                    //   ],
                    // ),
                    // const SizedBox(height: 15),
                    //
                    // // Google Sign In Button
                    // SizedBox(
                    //   width: double.infinity,
                    //   height: 48,
                    //   child: OutlinedButton.icon(
                    //     onPressed: _isLoading ? null : () => _continueWithGoogle(authService),
                    //     icon: const Icon(
                    //       Icons.g_mobiledata,
                    //       size: 22,
                    //       color: Color(0xFF4285F4),
                    //     ),
                    //     label: const Text(
                    //       'Continue with Google',
                    //       style: TextStyle(
                    //         fontSize: 13,
                    //         fontWeight: FontWeight.w600,
                    //         color: Color(0xFF2F3E1F),
                    //       ),
                    //     ),
                    //     style: OutlinedButton.styleFrom(
                    //       backgroundColor: Colors.white,
                    //       side: BorderSide(color: Colors.grey[300]!),
                    //       shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(10),
                    //       ),
                    //       disabledBackgroundColor: Colors.white.withOpacity(0.6),
                    //     ),
                    //   ),
                    // ),
                    // const SizedBox(height: 20),

                    // Sign Up Link
                    Container(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _primaryColor,
                              padding: const EdgeInsets.only(left: 6),
                              minimumSize: const Size(50, 30),
                            ),
                            child: Text(
                              'Sign Up',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}