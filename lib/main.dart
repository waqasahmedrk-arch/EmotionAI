import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lost_found/screens/verify_email_screen.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'model_host.dart';
import 'screens/diagnostic_screen.dart';
import 'screens/predict_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/send_otp_screen.dart';
// import 'screens/google_signin_screen.dart';
// import 'screens/google_otp_screen.dart';
import 'screens/add_google_account_screen.dart';
import 'screens/GuestLoginScreen.dart';
import 'screens/home_screen.dart'; // NEW: Import the separate home screen
import 'services/auth_service.dart';
import 'screens/visualization_screen.dart';
// import 'screens/mindwave_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ModelHost()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'EEG Prediction',
        theme: ThemeData(
          primaryColor: const Color(0xFF556B2F),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF556B2F),
          ),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/home': (context) => const HomeScreen(), // CHANGED: Now using separate HomeScreen
          '/guest-login': (context) => const GuestLoginScreen(),
          '/otp-verification': (context) => const SendOtpScreen(),
          '/verify-email': (context) => const VerifyEmailScreen(),

        },
      ),
    );
  }
}