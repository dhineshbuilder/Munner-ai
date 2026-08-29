import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_tab.dart';
import 'workouts_tab.dart';
import 'profile_tab.dart';
import '../services/workout_service.dart';

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
        title: const Text("முன்னேறு AI"),
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
