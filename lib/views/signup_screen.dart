import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/email_service.dart';
import '../controllers/auth_controller.dart';
import '../models/user_model.dart';  // 👈 ADDED - UserModel import

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthController _authController = AuthController();
  
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  File? _profileImage;
  
  String? _usernameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null && mounted) {
        setState(() {
          _profileImage = File(image.path);
        });
      }
    } catch (e) {
      _showError("Error picking image: $e");
    }
  }

  // Upload profile image to Firebase Storage
  Future<String?> _uploadProfileImage(String uid) async {
    if (_profileImage == null) return null;
    
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$uid.jpg');
      
      await ref.putFile(_profileImage!);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      return null;
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _usernameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
    
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();
    final String confirmPassword = _confirmPasswordController.text.trim();
    
    // Username validation
    if (username.isEmpty) {
      setState(() => _usernameError = "Please enter username");
      return;
    }
    
    if (username.length < 3) {
      setState(() => _usernameError = "Username must be at least 3 characters");
      return;
    }
    
    // Email validation
    if (email.isEmpty) {
      setState(() => _emailError = "Please enter email");
      return;
    }
    
    if (!email.endsWith('@gmail.com')) {
      setState(() => _emailError = "Email must be @gmail.com format");
      return;
    }
    
    if (!email.contains('@') || !email.contains('.com')) {
      setState(() => _emailError = "Please enter valid email address");
      return;
    }
    
    // Password validation
    if (password.isEmpty) {
      setState(() => _passwordError = "Please enter password");
      return;
    }
    
    if (password.length < 6) {
      setState(() => _passwordError = "Password must be at least 6 characters");
      return;
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      setState(() => _passwordError = "Password must contain at least 1 uppercase letter");
      return;
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      setState(() => _passwordError = "Password must contain at least 1 special character");
      return;
    }
    
    // Confirm password validation
    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = "Please confirm password");
      return;
    }
    
    if (password != confirmPassword) {
      setState(() => _confirmPasswordError = "Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create user in Firebase Authentication (using AuthController)
      final UserCredential userCredential = await _authController.signUpWithEmail(email, password);
      
      final String uid = userCredential.user!.uid;
      
      // 2. Update display name
      await userCredential.user?.updateDisplayName(username);
      
      // 3. Upload profile image to Firebase Storage (if selected)
      String? profileImageUrl = await _uploadProfileImage(uid);
      
      // 4. Save user data to Firestore (using AuthController)
      final userModel = UserModel(
        uid: uid,
        email: email,
        username: username,
        profileImageUrl: profileImageUrl ?? '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      await _authController.saveUserToFirestore(userModel);
      
      // 5. Send welcome email
      await EmailService.sendWelcomeEmail(email, username);
      
      if (!mounted) return;
      
      // 6. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 7. Go to Home Screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
      
    } on FirebaseAuthException catch (e) {
      String message = "Sign up failed";
      if (e.code == 'email-already-in-use') {
        message = "Email already registered. Please login.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format";
      } else if (e.code == 'weak-password') {
        message = "Password is too weak";
      }
      _showError(message);
    } catch (e) {
      _showError("Error: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 237, 243),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const _HeaderWidget(),
              const SizedBox(height: 30),
              _SignupFormWidget(
                usernameController: _usernameController,
                emailController: _emailController,
                passwordController: _passwordController,
                confirmPasswordController: _confirmPasswordController,
                isPasswordVisible: _isPasswordVisible,
                isConfirmPasswordVisible: _isConfirmPasswordVisible,
                usernameError: _usernameError,
                emailError: _emailError,
                passwordError: _passwordError,
                confirmPasswordError: _confirmPasswordError,
                isLoading: _isLoading,
                profileImage: _profileImage,
                onPickImage: _pickProfileImage,
                onSignUp: _signUp,
                onPasswordVisibilityToggle: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                onConfirmPasswordVisibilityToggle: () {
                  setState(() {
                    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                  });
                },
                onClearUsernameError: () {
                  setState(() => _usernameError = null);
                },
                onClearEmailError: () {
                  setState(() => _emailError = null);
                },
                onClearPasswordError: () {
                  setState(() => _passwordError = null);
                },
                onClearConfirmPasswordError: () {
                  setState(() => _confirmPasswordError = null);
                },
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
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

// ============ SEPARATE WIDGETS ============

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'Smart FinSight',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEC407A),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Voice Finance Tracker & Advisor',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _SignupFormWidget extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isPasswordVisible;
  final bool isConfirmPasswordVisible;
  final String? usernameError;
  final String? emailError;
  final String? passwordError;
  final String? confirmPasswordError;
  final bool isLoading;
  final File? profileImage;
  final VoidCallback onPickImage;
  final VoidCallback onSignUp;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onConfirmPasswordVisibilityToggle;
  final VoidCallback onClearUsernameError;
  final VoidCallback onClearEmailError;
  final VoidCallback onClearPasswordError;
  final VoidCallback onClearConfirmPasswordError;

  const _SignupFormWidget({
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isPasswordVisible,
    required this.isConfirmPasswordVisible,
    required this.usernameError,
    required this.emailError,
    required this.passwordError,
    required this.confirmPasswordError,
    required this.isLoading,
    required this.profileImage,
    required this.onPickImage,
    required this.onSignUp,
    required this.onPasswordVisibilityToggle,
    required this.onConfirmPasswordVisibilityToggle,
    required this.onClearUsernameError,
    required this.onClearEmailError,
    required this.onClearPasswordError,
    required this.onClearConfirmPasswordError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              'Create Account',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start tracking your finances',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            
            // Profile Image
            GestureDetector(
              onTap: onPickImage,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEC407A),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: profileImage != null
                      ? Image.file(
                          profileImage!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt,
                              size: 35,
                              color: Color(0xFF6B7280),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Add Photo',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Username
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Username",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: usernameController,
                  decoration: InputDecoration(
                    hintText: "Username",
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    errorText: usernameError,
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
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (_) => onClearUsernameError(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Email
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
                    hintText: "Email",
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    errorText: emailError,
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
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (_) => onClearEmailError(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Password
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
                      onPressed: onPasswordVisibilityToggle,
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
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (_) => onClearPasswordError(),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Confirm Password
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Confirm Password",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "Confirm Password",
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    errorText: confirmPasswordError,
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: onConfirmPasswordVisibilityToggle,
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
                      borderSide: const BorderSide(color: Colors.red),
                    ),
                  ),
                  onChanged: (_) => onClearConfirmPasswordError(),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Sign Up Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSignUp,
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
                        'Sign Up',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Login Link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Already have an account? ",
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text(
                    'Log In',
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
    );
  }
}