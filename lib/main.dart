import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'views/splash_screen.dart';
import 'views/login_screen.dart';
import 'views/signup_screen.dart';
import 'views/home_screen.dart';        
import 'views/forgot_password_screen.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    // ✅ LOAD .env FILE
  await dotenv.load(fileName: ".env");
  

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart FinSight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFEC407A),
        scaffoldBackgroundColor: const Color.fromARGB(255, 237, 237, 243),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2937),
          elevation: 0,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),  // 👈 New Home Screen
      },
    );
  }
}