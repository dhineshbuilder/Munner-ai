import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../main.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    
    if (!isSupabaseConfigured) {
      _showBypassNotice();
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Configure Google Sign-In Client
      const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '');
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: webClientId.isNotEmpty ? webClientId : null,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // User canceled the sign-in
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found from Google Sign-In.';
      }

      // 2. Authenticate with Supabase
      final AuthResponse response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user != null) {
        // Check if onboarding is required
        final profileExists = await _checkProfileExists(user.id);
        if (mounted) {
          if (profileExists) {
            Navigator.of(context).pushReplacementNamed('/home');
          } else {
            Navigator.of(context).pushReplacementNamed('/onboarding');
          }
        }
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Failed: ${e.toString()}"),
            action: SnackBarAction(
              label: 'Use Bypass',
              onPressed: _handleDeveloperBypass,
              textColor: const Color(0xFF38EF7D),
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      return false;
    }
  }

  void _handleDeveloperBypass() {
    setState(() {
      mockUserId = "dev-mock-uuid-999";
      mockUserEmail = "developer@munnerai.com";
      // Ensure we navigate correctly
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Logged in as mock developer user! Checking profile status..."),
        duration: Duration(seconds: 1),
      ),
    );

    // Call API to see if mock profile already exists in DB
    setState(() => _isLoading = true);
    ApiService.getMyProfile().then((profile) {
      setState(() => _isLoading = false);
      if (mounted) {
        if (profile != null && profile['username'] != 'mock_developer') {
          // If we have a custom saved mock profile
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          // Go to onboarding for brand new developer profile
          Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    });
  }

  void _showBypassNotice() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Development Mode"),
          content: const Text(
            "Supabase credentials are not configured in this build.\n\n"
            "You can use the 'Developer Bypass' mode to test the complete onboarding screens, "
            "FastAPI backend connection, and home screen immediately.",
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(120, 44),
                backgroundColor: const Color(0xFFFF4B2B),
              ),
              child: const Text("Bypass Auth"),
              onPressed: () {
                Navigator.of(context).pop();
                _handleDeveloperBypass();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF4B2B);

    return Scaffold(
      body: Stack(
        children: [
          // Elegant decorative gradient background circles
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38EF7D).withValues(alpha: 0.08),
              ),
            ),
          ),
          // Main Body Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Spacer(),
                    
                    // Logo Icon Concept (மு)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF4B2B), Color(0xFFFF6B4A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "மு", // Stylized Tamil Mu
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 54,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // App Name & Tamil Description
                    const Text(
                      "முன்னேறு AI",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "உன் ஆரோக்கிய முன்னேற்றம்", // Your health progress
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8E8E93),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    
                    const Spacer(),

                    // Login Button Section
                    _isLoading
                        ? const CircularProgressIndicator(color: primaryColor)
                        : Column(
                            children: [
                              // Google Button
                              ElevatedButton(
                                onPressed: _handleGoogleSignIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  elevation: 2,
                                  shadowColor: Colors.black.withValues(alpha: 0.1),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://developers.google.com/identity/images/g-logo.png',
                                      height: 24,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(Icons.account_circle, color: Colors.blue, size: 24);
                                      },
                                    ),
                                    const SizedBox(width: 14),
                                    const Text(
                                      "Continue with Google",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Developer Bypass Option
                              TextButton(
                                onPressed: _handleDeveloperBypass,
                                child: const Text(
                                  "Test Auth Bypass (Developer Mode)",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                    
                    const SizedBox(height: 16),
                    // Safety / Regulatory subtext
                    const Text(
                      "By continuing, you agree to our terms of service.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF636366),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
