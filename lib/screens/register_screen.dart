import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'calendar_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const bgColor = Color(0xFFFEF8E8);
  static const primaryColor = Color(0xFF0F172A);
  static const accentColor = Color(0xFFFAC638);
  static const secondaryAccent = Color(0xFFF59E0B);
  static const labelColor = Color(0xFF1E293B);
  static const hintColor = Color(0xFF64748B);
  static const placeholderColor = Color(0xFF94A3B8);
  static const borderColor = Color(0xFFE2E8F0);
  static const fieldBackgroundColor = bgColor;
  static const fieldBorderColor = Color(0xFFDDE2E7);

  final fullNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  String? _validateInputs() {
    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (fullName.isEmpty) {
      return 'Please enter your full name.';
    }

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _register() async {
    final validationMessage = _validateInputs();
    if (validationMessage != null) {
      _showMessage(validationMessage);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final fullName = fullNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      final credential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        _showMessage('Registration failed. Please try again.');
        return;
      }

      await user.updateDisplayName(fullName);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': email,
        'bio': '',
        'photoURL': '',
        'status': 'active',
        'username': fullName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Account created successfully.');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const CalendarScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed. Please try again.';

      if (e.code == 'email-already-in-use') {
        message = 'This email is already in use.';
      } else if (e.code == 'invalid-email') {
        message = 'The email address is invalid.';
      } else if (e.code == 'weak-password') {
        message = 'The password is too weak.';
      } else if (e.code == 'operation-not-allowed') {
        message =
        'Email/password sign-in is not enabled in Firebase Console.';
      }

      _showMessage(message);
    } catch (e) {
      _showMessage('Something went wrong: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildLogoHeader(),
                    const SizedBox(height: 24),
                    _buildRegisterCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildLogoHeader() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.center,
  //     children: [
  //       Container(
  //         width: 92,
  //         height: 92,
  //         decoration: BoxDecoration(
  //           gradient: RadialGradient(
  //             colors: [
  //               accentColor.withOpacity(0.22),
  //               Colors.white.withOpacity(0.0),
  //             ],
  //             radius: 0.8,
  //           ),
  //           border: Border.all(
  //             color: accentColor.withOpacity(0.2),
  //             width: 1.2,
  //           ),
  //           borderRadius: BorderRadius.circular(100),
  //           boxShadow: [
  //             BoxShadow(
  //               color: accentColor.withOpacity(0.12),
  //               blurRadius: 20,
  //               offset: const Offset(0, 8),
  //             ),
  //           ],
  //         ),
  //         child: const Center(
  //           child: Icon(
  //             Icons.location_on,
  //             size: 42,
  //             color: accentColor,
  //           ),
  //         ),
  //       ),
  //       const SizedBox(height: 16),
  //       const Text(
  //         'Cottage',
  //         style: TextStyle(
  //           fontSize: 30,
  //           fontWeight: FontWeight.bold,
  //           color: primaryColor,
  //           letterSpacing: -0.75,
  //           fontFamily: 'Plus Jakarta Sans',
  //         ),
  //       ),
  //       const SizedBox(height: 8),
  //       Text(
  //         'Your family\'s shared space',
  //         style: TextStyle(
  //           fontSize: 14,
  //           fontWeight: FontWeight.w500,
  //           color: Color(0xFF7E7664),
  //           fontFamily: 'Plus Jakarta Sans',
  //         ),
  //       ),
  //     ],
  //   );
  // }
  Widget _buildLogoHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/family_memo_logo.png',
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFullNameField(),
            const SizedBox(height: 18),
            _buildEmailField(),
            const SizedBox(height: 18),
            _buildPasswordField(),
            const SizedBox(height: 28),
            _buildCreateAccountButton(),
            const SizedBox(height: 24),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildFullNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Full Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: fieldBorderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: fullNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: TextStyle(
                  color: placeholderColor,
                  fontSize: 16,
                  fontFamily: 'Plus Jakarta Sans',
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: primaryColor,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: fieldBorderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                hintText: 'name@example.com',
                hintStyle: TextStyle(
                  color: placeholderColor,
                  fontSize: 16,
                  fontFamily: 'Plus Jakarta Sans',
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: primaryColor,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: labelColor,
            fontFamily: 'Plus Jakarta Sans',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: fieldBackgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: fieldBorderColor, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: TextField(
              controller: passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isLoading ? null : _register(),
              decoration: const InputDecoration(
                hintText: 'Create a secure password',
                hintStyle: TextStyle(
                  color: placeholderColor,
                  fontSize: 16,
                  fontFamily: 'Plus Jakarta Sans',
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: 16,
                color: primaryColor,
                fontFamily: 'Plus Jakarta Sans',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreateAccountButton() {
    return Opacity(
      opacity: _isLoading ? 0.85 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [accentColor, secondaryAccent],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _register,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Create Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: hintColor,
            fontFamily: 'Plus Jakarta Sans',
          ),
          children: [
            const TextSpan(text: 'Already have an account? '),
            TextSpan(
              text: 'Sign In',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: secondaryAccent,
              ),
              recognizer: TapGestureRecognizer()..onTap = _goToLogin,
            ),
          ],
        ),
      ),
    );
  }
}