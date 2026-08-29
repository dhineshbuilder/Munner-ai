import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    final data = await ApiService.getMyProfile();
    
    if (mounted) {
      if (data != null) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load user profile. Please check backend connection.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    if (isSupabaseConfigured) {
      await Supabase.instance.client.auth.signOut();
    } else {
      mockUserId = "";
      mockUserEmail = "";
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF4B2B);
    const accentColor = Color(0xFF38EF7D);

    return Scaffold(
      appBar: AppBar(
        title: const Text("முன்னேறு AI"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        color: primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: primaryColor))
            : _errorMessage.isNotEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height - 150,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _fetchProfile,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(180, 50),
                            ),
                            child: const Text("TRY RECONNECT"),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcoming Card
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: primaryColor.withValues(alpha: 0.2),
                              child: Text(
                                _profileData?['username']?[0]?.toUpperCase() ?? "M",
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "வணக்கம் (Hello),",
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "@${_profileData?['username'] ?? 'username'}",
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Thirukkural Quote Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: accentColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.auto_awesome, color: accentColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      "MOTIVATION FOR TODAY",
                                      style: TextStyle(
                                        color: accentColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  "\"முயற்சி திருவினையாக்கும்.\"",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Effort yields success and elevates your life. Keep pushing forward!",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[400],
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Profile Details Card
                        const Text(
                          "YOUR STATISTICS (உங்கள் விவரங்கள்)",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  icon: Icons.cake,
                                  label: "Age (வயது)",
                                  value: "${_profileData?['age'] ?? '-'} years",
                                ),
                                const Divider(height: 1, indent: 64),
                                _buildStatRow(
                                  icon: Icons.height,
                                  label: "Height (உயரம்)",
                                  value: "${_profileData?['height'] ?? '-'} cm",
                                ),
                                const Divider(height: 1, indent: 64),
                                _buildStatRow(
                                  icon: Icons.scale,
                                  label: "Weight (எடை)",
                                  value: "${_profileData?['weight'] ?? '-'} kg",
                                ),
                                const Divider(height: 1, indent: 64),
                                _buildStatRow(
                                  icon: Icons.phone,
                                  label: "Phone (தொலைபேசி)",
                                  value: _profileData?['phone_number'] ?? '-',
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Next Step placeholder
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.directions_run, size: 48, color: primaryColor),
                              const SizedBox(height: 12),
                              const Text(
                                "Ready for your fitness journey?",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Stay tuned! Workout planning module will be unlocked in the next build.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 24),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
