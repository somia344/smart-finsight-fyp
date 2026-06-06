import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    final User? user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  final Color primaryPink = const Color(0xFFEC407A);
  final Color backgroundColor = const Color.fromARGB(255, 237, 237, 243);  
  final Color textSecondary = const Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Text(
              'Smart FinSight',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: primaryPink,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Voice Finance Tracker & Advisor',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(flex: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(primaryPink.withValues(alpha: 0.4)),
                const SizedBox(width: 8),
                _buildDot(primaryPink.withValues(alpha: 0.7)),
                const SizedBox(width: 8),
                _buildDot(primaryPink),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              'Loading...',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}