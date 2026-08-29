import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_tab.dart';
import 'workouts_tab.dart';
import 'profile_tab.dart';
import '../services/workout_service.dart';
import '../services/audio_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  final WorkoutService _workoutService = WorkoutService();

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeTab(onNavigateToWorkouts: () {
        setState(() {
          _currentIndex = 1; // Index of WorkoutsTab
        });
      }),
      const WorkoutsTab(),
      const ProfileTab(),
    ];
    
    // Check if there's an active workout session in progress to offer recovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkActiveSessionRecovery();
    });

    // Start background alarm watcher
    _workoutService.startAlarmTicker(
      onTrigger: (hour, minute) {
        if (mounted) {
          _showAlarmAlertDialog(hour, minute);
        }
      },
    );
  }

  void _showAlarmAlertDialog(int hour, int minute) {
    final period = hour >= 12 ? "PM" : "AM";
    final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    final timeStr = "$h:$m $period";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final primaryColor = Theme.of(dialogContext).primaryColor;
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.alarm_on_rounded, color: primaryColor, size: 28),
              ),
              const SizedBox(width: 14),
              const Text(
                "Workout Alarm!",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "It's $timeStr — time to build your progress with today's routine!",
                style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                "Stay consistent and keep your streak alive.",
                style: TextStyle(color: Color(0xFFA0A0A5), fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                AudioService().stop();
                Navigator.pop(dialogContext);
              },
              child: const Text("Dismiss", style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                HapticFeedback.heavyImpact();
                AudioService().stop();
                Navigator.pop(dialogContext);
                Navigator.pushNamed(context, '/player');
              },
              child: const Text(
                "Start Workout",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkActiveSessionRecovery() async {
    final activeSession = _workoutService.activeSession;
    if (activeSession != null) {
      final activePlan = _workoutService.plans.firstWhere(
        (p) => p.id == activeSession.planId,
        orElse: () => _workoutService.plans.first,
      );

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text("Resume Workout?"),
            content: const Text(
              "We noticed you have a workout session in progress. Would you like to resume where you left off?",
              style: TextStyle(color: Color(0xFFA0A0A5)),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _workoutService.clearActiveSession();
                  Navigator.pop(context);
                },
                child: const Text("Start Over", style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed(
                    '/player',
                    arguments: {
                      'plan': activePlan,
                      'dayOfWeek': activeSession.dayOfWeek,
                      'resume': true,
                    },
                  );
                },
                child: Text("Resume", style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "MunnerAI",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: Image.asset(
            'assets/icon/app_icon.png',
            width: 36,
            height: 36,
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center, size: 28),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: const Color(0xFFA0A0A5),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center_outlined),
            activeIcon: Icon(Icons.fitness_center),
            label: "Workouts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
