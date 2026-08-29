import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

// Global config for Mock/Bypass mode
bool isSupabaseConfigured = false;
String mockUserEmail = "";
String mockUserId = "";

// Configurable FastAPI backend URL
// 10.0.2.2 is the localhost loopback for Android Emulators.
// 127.0.0.1/localhost is for iOS emulators or desktop testing.
String backendUrl = "http://172.29.132.146:8000"; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try to load Supabase settings from Dart environmental variables
  // Example run command: flutter run --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=yyy
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
      );
      isSupabaseConfigured = true;
      debugPrint("Supabase successfully initialized.");
    } catch (e) {
      debugPrint("Error initializing Supabase: $e. Falling back to Developer Bypass mode.");
    }
  } else {
    debugPrint("Supabase credentials not found in --dart-define. Starting in Developer Bypass mode.");
  }

  runApp(const MunnerAiApp());
}

class MunnerAiApp extends StatelessWidget {
  const MunnerAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Brand Color Palette
    const primaryColor = Color(0xFFFF4B2B); // Sunset Vermillion
    const accentColor = Color(0xFF38EF7D);  // Electric Mint
    const backgroundColor = Color(0xFF0F0F11); // Obsidian Dark
    const surfaceColor = Color(0xFF1A1A1E); // Dark Slate Card

    return MaterialApp(
      title: 'முன்னேறு AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: accentColor,
          surface: surfaceColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: surfaceColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: primaryColor, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
          floatingLabelStyle: const TextStyle(color: primaryColor),
        ),
      ),
      // Define screens
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

// Logic to check auth status and route accordingly
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseConfigured) {
      // If not configured, go straight to login screen with bypass mode enabled
      return const LoginScreen();
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return const LoginScreen();
    }

    // User is logged in, check if onboarding is complete
    return FutureBuilder<bool>(
      future: _checkProfileExists(session.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4B2B)),
            ),
          );
        }

        if (snapshot.data == true) {
          return const HomeScreen();
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }

  // Returns true if user has completed onboarding profile
  Future<bool> _checkProfileExists(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint("Error checking profile status: $e");
      return false;
    }
  }
}
