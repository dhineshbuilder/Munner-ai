import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart'; // import global settings

class ApiService {
  // Check if username is available (live validation)
  static Future<bool> checkUsernameAvailability(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/profiles/check-username?username=$username'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['available'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("Error calling check-username API: $e");
      // Fallback: simple client-side check if backend is unreachable
      if (username.toLowerCase() == 'admin' || username.toLowerCase() == 'taken') {
        return false;
      }
      return true; 
    }
  }

  // Create user profile in db via FastAPI
  static Future<Map<String, dynamic>?> createProfile({
    required String username,
    required int age,
    required double height,
    required double weight,
    required String phoneNumber,
  }) async {
    final token = _getAuthToken();
    
    final payload = {
      'username': username,
      'age': age,
      'height': height,
      'weight': weight,
      'phone_number': phoneNumber,
    };

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/profiles/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint("Backend error onboarding profile: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("Network error connecting to backend API: $e");
      
      // Fallback mock write to local storage if running in mock/local mode
      if (!isSupabaseConfigured) {
        return {
          'id': mockUserId,
          'username': username,
          'age': age,
          'height': height,
          'weight': weight,
          'phone_number': phoneNumber,
        };
      }
      return null;
    }
  }

  // Retrieve current profile
  static Future<Map<String, dynamic>?> getMyProfile() async {
    final token = _getAuthToken();
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/api/profiles/me'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("Network error fetching profile: $e");
      if (!isSupabaseConfigured) {
        return {
          'id': mockUserId,
          'username': 'mock_developer',
          'age': 25,
          'height': 175.0,
          'weight': 70.0,
          'phone_number': '+919876543210',
        };
      }
      return null;
    }
  }

  // Helper to fetch active JWT token
  static String _getAuthToken() {
    if (!isSupabaseConfigured) {
      return "mock_developer_jwt_token"; // Dev bypass header token
    }
    final session = Supabase.instance.client.auth.currentSession;
    return session?.accessToken ?? "";
  }
}
