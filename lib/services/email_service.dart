import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Configure these with your email service credentials
  static const String _smtpUsername = 'waqasah652@@gmail.com'; // Your email
  static const String _smtpPassword = 'pumg phmt fvqi nvid';    // App password

  static Future<bool> sendVerificationEmail(String email, String otp) async {
    try {
      // Create SMTP server for Gmail
      final smtpServer = gmail(_smtpUsername, _smtpPassword);

      final message = Message()
        ..from = Address(_smtpUsername, 'EEG Prediction App')
        ..recipients.add(email)
        ..subject = 'Email Verification OTP - EEG Prediction App'
        ..html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background-color: #f4f4f4; 
            margin: 0; 
            padding: 20px; 
        }
        .container { 
            max-width: 600px; 
            margin: 0 auto; 
            background: white; 
            padding: 30px; 
            border-radius: 10px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
        .header { 
            color: #556B2F; 
            text-align: center; 
            margin-bottom: 30px; 
        }
        .otp-container { 
            background: #E8EFDF; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            margin: 20px 0; 
        }
        .otp-code { 
            font-size: 32px; 
            font-weight: bold; 
            color: #556B2F; 
            letter-spacing: 5px; 
        }
        .footer { 
            margin-top: 30px; 
            padding-top: 20px; 
            border-top: 1px solid #ddd; 
            color: #666; 
            font-size: 14px; 
        }
        .note {
            background: #fff3cd;
            padding: 10px;
            border-radius: 5px;
            border-left: 4px solid #ffc107;
            margin: 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔐 Email Verification</h1>
        </div>
        
        <p>Hello,</p>
        
        <p>Thank you for signing up with <strong>EEG Prediction App</strong>. Use the following OTP to verify your email address:</p>
        
        <div class="otp-container">
            <div class="otp-code">$otp</div>
        </div>
        
        <div class="note">
            <strong>⚠️ Important:</strong> This OTP will expire in <strong>5 minutes</strong>.
        </div>
        
        <p>If you didn't request this verification, please ignore this email.</p>
        
        <div class="footer">
            <p>Best regards,<br><strong>EEG Prediction App Team</strong></p>
        </div>
    </div>
</body>
</html>
""";

      // Send the email
      await send(message, smtpServer);
      return true;
    } catch (e) {
      // Log error but don't expose to user
      print('Email sending error: ${e.toString()}');
      return false;
    }
  }

  static Future<bool> sendPasswordResetEmail(String email, String otp) async {
    try {
      final smtpServer = gmail(_smtpUsername, _smtpPassword);

      final message = Message()
        ..from = Address(_smtpUsername, 'EEG Prediction App')
        ..recipients.add(email)
        ..subject = 'Password Reset OTP - EEG Prediction App'
        ..html = """
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { 
            font-family: Arial, sans-serif; 
            background-color: #f4f4f4; 
            margin: 0; 
            padding: 20px; 
        }
        .container { 
            max-width: 600px; 
            margin: 0 auto; 
            background: white; 
            padding: 30px; 
            border-radius: 10px; 
            box-shadow: 0 2px 10px rgba(0,0,0,0.1); 
        }
        .header { 
            color: #556B2F; 
            text-align: center; 
            margin-bottom: 30px; 
        }
        .otp-container { 
            background: #E8EFDF; 
            padding: 20px; 
            border-radius: 8px; 
            text-align: center; 
            margin: 20px 0; 
        }
        .otp-code { 
            font-size: 32px; 
            font-weight: bold; 
            color: #556B2F; 
            letter-spacing: 5px; 
        }
        .footer { 
            margin-top: 30px; 
            padding-top: 20px; 
            border-top: 1px solid #ddd; 
            color: #666; 
            font-size: 14px; 
        }
        .note {
            background: #fff3cd;
            padding: 10px;
            border-radius: 5px;
            border-left: 4px solid #ffc107;
            margin: 15px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔄 Password Reset</h1>
        </div>
        
        <p>Hello,</p>
        
        <p>You requested to reset your password for <strong>EEG Prediction App</strong>. Use the following OTP to proceed:</p>
        
        <div class="otp-container">
            <div class="otp-code">$otp</div>
        </div>
        
        <div class="note">
            <strong>⚠️ Important:</strong> This OTP will expire in <strong>5 minutes</strong>.
        </div>
        
        <p>If you didn't request a password reset, please ignore this email.</p>
        
        <div class="footer">
            <p>Best regards,<br><strong>EEG Prediction App Team</strong></p>
        </div>
    </div>
</body>
</html>
""";

      // Send the email
      await send(message, smtpServer);
      return true;
    } catch (e) {
      // Log error but don't expose to user
      print('Password reset email error: ${e.toString()}');
      return false;
    }
  }
}