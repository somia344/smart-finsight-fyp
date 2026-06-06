import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmailService {
  static const String brevoApiUrl = 'https://api.brevo.com/v3/smtp/email';
  
  // Send welcome email after signup
  static Future<bool> sendWelcomeEmail(String toEmail, String username) async {
    try {
      final apiKey = dotenv.env['BREVO_API_KEY'] ?? '';
      final fromEmail = dotenv.env['BREVO_EMAIL'] ?? '';
      
      if (apiKey.isEmpty || fromEmail.isEmpty) {
        return false;
      }
      
      final response = await http.post(
        Uri.parse(brevoApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: json.encode({
          'sender': {'email': fromEmail, 'name': 'Smart FinSight'},
          'to': [{'email': toEmail, 'name': username}],
          'subject': 'Welcome to Smart FinSight! 🎉',
          'htmlContent': '''
            <!DOCTYPE html>
            <html>
            <head>
              <style>
                body { font-family: Arial, sans-serif; background-color: #f4f4f4; margin: 0; padding: 20px; }
                .container { max-width: 600px; margin: 0 auto; background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .header { background: #EC407A; padding: 30px; text-align: center; }
                .header h1 { color: white; margin: 0; font-size: 28px; }
                .content { padding: 30px; }
                .content h2 { color: #1F2937; margin-top: 0; }
                .content p { color: #6B7280; line-height: 1.6; }
                .button { display: inline-block; background: #EC407A; color: white; padding: 12px 30px; text-decoration: none; border-radius: 8px; margin-top: 20px; }
                .footer { background: #F3F4F6; padding: 20px; text-align: center; color: #6B7280; font-size: 12px; }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <h1>Smart FinSight</h1>
                  <p style="color: white; opacity: 0.9;">Voice Finance Tracker & Advisor</p>
                </div>
                <div class="content">
                  <h2>Welcome, $username! 👋</h2>
                  <p>Thank you for joining Smart FinSight! We're excited to help you take control of your finances.</p>
                  <p>With Smart FinSight, you can:</p>
                  <ul>
                    <li>Track your income and expenses</li>
                    <li>Add transactions using voice</li>
                    <li>View insightful charts and reports</li>
                    <li> Get smart financial suggestions</li>
                    <li>Receive budget warnings and reminders</li>
                  </ul>
                  <p>Start your financial journey today and achieve your money goals!</p>
                </div>
                <div class="footer">
                  <p>&copy; 2026 Smart FinSight. All rights reserved.</p>
                  <p>You're receiving this email because you created an account with Smart FinSight.</p>
                </div>
              </div>
            </body>
            </html>
          ''',
        }),
      );
      
      return response.statusCode == 201;
      
    } catch (e) {
      return false;
    }
  }
  
  // Send password reset email (using Firebase)
  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}