// login_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'popup_page.dart';
import 'main.dart'; // where flutterLocalNotificationsPlugin is initialized
import 'home_screen.dart'; // <-- The new home screen

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 1. ADDED: Key for Form Validation
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  // State variables
  bool isLogin = true;
  bool _isLoading = false; // 2. ADDED: Loading state for button

  // Firebase instances
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // 3. ADDED: Dispose controllers
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 4. ADDED: Validate form
    if (!_formKey.currentState!.validate()) {
      return; // If form is invalid, do nothing
    }

    setState(() {
      _isLoading = true; // Show loading spinner
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (isLogin) {
        // --- LOGIN ---
        final userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Get FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('🔥 FCM Token: $fcmToken');

        // Send token to backend
        await http.post(
          Uri.parse('https://login-popup-backend.onrender.com//register-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': userCredential.user!.uid,
            'email': email,
            'token': fcmToken,
          }),
        );

        // Local notification
        await flutterLocalNotificationsPlugin.show(
          0,
          'Login Successful',
          'You have successfully logged in!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'login_channel',
              'Login Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      } else {
        // --- REGISTER ---
        final userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': email,
        });

        // Get FCM token
        final fcmToken = await FirebaseMessaging.instance.getToken();

        // Send token to backend
        await http.post(
          Uri.parse('https://login-popup-backend.onrender.com//register-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': userCredential.user!.uid,
            'email': email,
            'token': fcmToken,
          }),
        );

        // Local notification
        await flutterLocalNotificationsPlugin.show(
          0,
          'Registration Successful',
          'Welcome to the app!',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'register_channel',
              'Registration Notifications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }

      // --- COMMON LOGIC (After Login or Register) ---

      // Fetch user data
      final userDoc =
          await firestore.collection('users').doc(auth.currentUser!.uid).get();
      final userData = userDoc.data();

      if (!mounted) return;

      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User data not found!')),
        );
        return;
      }

      // 5. UPDATED: Await the pop-up
      await showDialog(
        context: context,
        builder: (_) => PopupPage(userData: userData),
      );

      if (!mounted) return;

      // 6. ADDED: Navigate to Home Screen after pop-up closes
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WhatsAppHome()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      // 7. ADDED: Always stop loading state
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Register'),
      ),
      // 8. ADDED: SingleChildScrollView to prevent keyboard overflow
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        // 9. ADDED: Form widget for validation
        child: Form(
          key: _formKey, // Attach form key
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isLogin)
                // 10. CHANGED: to TextFormField
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter your name' : null,
                ),
              const SizedBox(height: 16),
              // 10. CHANGED: to TextFormField
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty || !value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // 10. CHANGED: to TextFormField
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // 11. UPDATED: ElevatedButton for loading state
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  // Disable button when loading, or call _submit
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isLogin ? 'Login' : 'Register'),
                ),
              ),
              TextButton(
                // Disable button when loading
                onPressed: _isLoading ? null : () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin ? 'Create an account' : 'Already have an account?',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}