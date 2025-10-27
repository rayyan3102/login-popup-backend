import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- THESE IMPORTS ARE NO LONGER NEEDED IN THIS FILE ---
// import 'popup_page.dart';
// import 'home_screen.dart'; 

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool isLogin = true;
  bool _isLoading = false;

  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // --- THIS IS THE ONLY FUNCTION THAT HAS CHANGED ---
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      UserCredential userCredential; // Declare here to use in both blocks

      if (isLogin) {
        // --- LOGIN ---
        userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final fcmToken = await FirebaseMessaging.instance.getToken();
        print('🔥 FCM Token: $fcmToken');

        // Send the token (this is great, keep it!)
        await http.post(
          Uri.parse('https://login-popup-backend.onrender.com/register-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': userCredential.user!.uid,
            'email': email,
            'token': fcmToken,
          }),
        );

        // Show a local notification (this is fine!)
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
        userCredential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        await firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameController.text.trim(),
          'email': email,
        });

        final fcmToken = await FirebaseMessaging.instance.getToken();

        // Send the token
        await http.post(
          Uri.parse('https://login-popup-backend.onrender.com/register-token'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'uid': userCredential.user!.uid,
            'email': email,
            'token': fcmToken,
          }),
        );

        // Show a local notification
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

      // --- ALL LOGIC AFTER THIS POINT IS REMOVED ---
      
      // We do NOT fetch user data here.
      // We do NOT show a PopupPage here.
      // We do NOT navigate here.

      // The StreamBuilder in main.dart is now handling all navigation.
      // As soon as this 'try' block finishes, the StreamBuilder
      // will see the new user and automatically switch to WhatsAppHome.

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Build method is unchanged ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Login' : 'Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isLogin)
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isLogin ? 'Login' : 'Register'),
                ),
              ),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
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