import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 2;

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  // Input Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Username validation state
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String _usernameError = "";
  Timer? _debounceTimer;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // Debounced live username availability check
  void _onUsernameChanged(String val) {
    _debounceTimer?.cancel();
    if (val.length < 3) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = "Must be at least 3 characters";
      });
      return;
    }

    final RegExp regex = RegExp(r"^[a-zA-Z0-9_]+$");
    if (!regex.hasMatch(val)) {
      setState(() {
        _isUsernameAvailable = false;
        _usernameError = "Only alphanumeric and underscores allowed";
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = "";
    });

    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      final available = await ApiService.checkUsernameAvailability(val);
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = available;
          _usernameError = available ? "" : "Username is already taken";
        });
      }
    });
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_step1Key.currentState!.validate() && _isUsernameAvailable) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_step2Key.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final String username = _usernameController.text.trim();
    final String phone = _phoneController.text.trim();
    final int age = int.parse(_ageController.text.trim());
    final double height = double.parse(_heightController.text.trim());
    final double weight = double.parse(_weightController.text.trim());

    final response = await ApiService.createProfile(
      username: username,
      age: age,
      height: height,
      weight: weight,
      phoneNumber: phone,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile configured successfully! Welcome to MunnerAI!"),
            backgroundColor: Color(0xFF38EF7D),
          ),
        );
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to submit profile. Please verify connection to backend."),
            backgroundColor: Color(0xFFFF4B2B),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFFF4B2B);

    return Scaffold(
      appBar: AppBar(
        title: const Text("உங்களைப்பற்றி (About You)"),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: _prevStep,
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Custom linear progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    width: MediaQuery.of(context).size.width * ((_currentStep + 1) / _totalSteps) - 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryColor, Color(0xFFFF6B4A)],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            
            // Steps view
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() => _currentStep = page);
                },
                children: [
                  _buildStep1(),
                  _buildStep2(),
                ],
              ),
            ),

            // Controls footer
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _currentStep == _totalSteps - 1
                  ? ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitOnboarding,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text("FINISH PROFILE (முழுமையாக்கு)"),
                    )
                  : ElevatedButton(
                      onPressed: _isUsernameAvailable && !_isCheckingUsername ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUsernameAvailable && !_isCheckingUsername
                            ? primaryColor
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      child: const Text("CONTINUE (தொடர்க)"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    const accentColor = Color(0xFF38EF7D);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _step1Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              "Choose your identity",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your username must be unique. Choose a name that motivates you.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Username Field
            const Text(
              "USERNAME (பயனர் பெயர்)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              onChanged: _onUsernameChanged,
              keyboardType: TextInputType.text,
              style: const TextStyle(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: "e.g., fit_beast_99",
                prefixIcon: const Icon(Icons.alternate_email, color: Colors.grey),
                suffixIcon: _isCheckingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(14.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF4B2B)),
                        ),
                      )
                    : _usernameController.text.isNotEmpty
                        ? Icon(
                            _isUsernameAvailable ? Icons.check_circle : Icons.error,
                            color: _isUsernameAvailable ? accentColor : Colors.red,
                          )
                        : null,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Username is required";
                if (val.trim().length < 3) return "Must be at least 3 characters";
                if (!_isUsernameAvailable) return _usernameError.isNotEmpty ? _usernameError : "Username is taken";
                return null;
              },
            ),
            
            // Availability Helper Text
            if (_usernameController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  _isCheckingUsername
                      ? "Checking availability..."
                      : _isUsernameAvailable
                          ? "✓ Username is available!"
                          : "✗ $_usernameError",
                  style: TextStyle(
                    fontSize: 13,
                    color: _isCheckingUsername
                        ? Colors.grey
                        : _isUsernameAvailable
                            ? accentColor
                            : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Phone Number Field
            const Text(
              "PHONE NUMBER (தொலைபேசி எண்)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: "+91 98765 43210",
                prefixIcon: Icon(Icons.phone, color: Colors.grey),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Phone number is required";
                if (val.trim().length < 7 || val.trim().length > 17) {
                  return "Invalid phone number length";
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Form(
        key: _step2Key,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              "Your physical stats",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We use these metrics to calibrate progression levels and track stats.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),

            // Age Field
            const Text(
              "AGE (வயது)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "e.g., 25",
                prefixIcon: Icon(Icons.cake, color: Colors.grey),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Age is required";
                final parsed = int.tryParse(val);
                if (parsed == null || parsed <= 0 || parsed >= 120) {
                  return "Please enter a valid age (1-119)";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Height Field
            const Text(
              "HEIGHT (உயரம் - cm)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: "e.g., 175.5",
                prefixIcon: Icon(Icons.height, color: Colors.grey),
                suffixText: "cm",
                suffixStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Height is required";
                final parsed = double.tryParse(val);
                if (parsed == null || parsed <= 30 || parsed >= 300) {
                  return "Please enter a valid height (30-300 cm)";
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Weight Field
            const Text(
              "WEIGHT (எடை - kg)",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                hintText: "e.g., 72.8",
                prefixIcon: Icon(Icons.scale, color: Colors.grey),
                suffixText: "kg",
                suffixStyle: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return "Weight is required";
                final parsed = double.tryParse(val);
                if (parsed == null || parsed <= 10 || parsed >= 500) {
                  return "Please enter a valid weight (10-500 kg)";
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
