import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../controllers/auth_controller.dart';  // 👈 SIRF YEH IMPORT ADD HOGA

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = AuthController();  // 👈 YEH ADD HOGA
  
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isGoogleLoading = false;
  bool isPasswordVisible = false;
  
  // Validation error messages
  String? emailError;
  String? passwordError;

  // EMAIL LOGIN with validation
  Future<void> loginWithEmail() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    
    // Reset errors
    setState(() {
      emailError = null;
      passwordError = null;
    });
    
    // Email validation
    if (email.isEmpty) {
      setState(() => emailError = "Please enter email");
      return;
    }
    
    // Email format validation - must be @gmail.com
    if (!email.endsWith('@gmail.com')) {
      setState(() => emailError = "Email must be @gmail.com format");
      return;
    }
    
    if (!email.contains('@') || !email.contains('.com')) {
      setState(() => emailError = "Please enter valid email address");
      return;
    }
    
    // Password validation
    if (password.isEmpty) {
      setState(() => passwordError = "Please enter password");
      return;
    }
    
    // Password validation: minimum 6 chars, 1 uppercase, 1 special character
    if (password.length < 6) {
      setState(() => passwordError = "Password must be at least 6 characters");
      return;
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      setState(() => passwordError = "Password must contain at least 1 uppercase letter");
      return;
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      setState(() => passwordError = "Password must contain at least 1 special character (!@#\$%^&* etc.)");
      return;
    }

    setState(() => isLoading = true);

    try {
      // 👇 YEH LINE CHANGE HOGI (Controller use karega)
      await _authController.signInWithEmail(email, password);
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";
      if (e.code == 'user-not-found') {
        message = "No user found. Please sign up first.";
      } else if (e.code == 'wrong-password') {
        message = "Wrong password.";
      } else if (e.code == 'invalid-credential') {
        message = "Invalid credential";
      }
      _showError(message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // GOOGLE LOGIN
  Future<void> loginWithGoogle() async {
    setState(() => isGoogleLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      
      if (googleUser == null) {
        _showError("Google Sign In was cancelled");
        setState(() => isGoogleLoading = false);
        return;
      }
      
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      
    } catch (e) {
      _showError("Google login error: ${e.toString()}");
      setState(() => isGoogleLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFEC407A)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 237, 243),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 30),
                const Text(
                  'Smart FinSight',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEC407A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Voice Finance Tracker & Advisor',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // WHITE CARD
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to continue tracking',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Email Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Email",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: "Enter your email",
                                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                                errorText: emailError,
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEC407A),
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Colors.red),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (emailError != null) emailError = null;
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Password Field
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Password",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: passwordController,
                              obscureText: !isPasswordVisible,
                              decoration: InputDecoration(
                                hintText: "Password",
                                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                                errorText: passwordError,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: const Color(0xFF6B7280),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      isPasswordVisible = !isPasswordVisible;
                                    });
                                  },
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF3F4F6),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFEC407A),
                                  ),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFEC407A)),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (passwordError != null) passwordError = null;
                                });
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Forgot Password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                                   Navigator.pushNamed(context, '/forgot-password');
                                   },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color(0xFFEC407A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : loginWithEmail,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEC407A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // OR Divider
                        const Row(
                          children: [
                            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'or',
                                style: TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ),
                            Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Google Sign In Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: isGoogleLoading ? null : loginWithGoogle,
                            icon: isGoogleLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFEC407A),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : ClipOval(
                                    child: Container(
                                      color: Colors.white,
                                      padding: const EdgeInsets.all(2),
                                      child: Image.asset(
                                        'assets/images/google logo.png',
                                        width: 20,
                                        height: 20,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const Icon(Icons.g_mobiledata, color: Color(0xFF4285F4), size: 22);
                                        },
                                      ),
                                    ),
                                  ),
                            label: Text(
                              isGoogleLoading ? '' : 'Continue with Google',
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Sign Up Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pushReplacementNamed(context, '/signup');
                              },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFFEC407A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}