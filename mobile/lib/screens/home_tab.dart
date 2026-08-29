import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onNavigateToWorkouts;
  const HomeTab({super.key, required this.onNavigateToWorkouts});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final WorkoutService _workoutService = WorkoutService();
  Timer? _walkTimer;
  String _quote = "";

  final List<String> _quotes = [
    "Small progress every day becomes a big change.",
    "முன்னேறு: தொடர் முயற்சியே வெற்றியின் அடிப்படை.",
    "Your body can stand almost anything. It's your mind that you have to convince.",
    "இன்றைய உழைப்பு நாளைய உயர்வு.",
    "Consistency is the key to unlocking your true potential.",
    "வழி எது என்று தேடாதே, வழியை உருவாக்கு.",
    "Don't limit your challenges. Challenge your limits."
  ];

  @override
  void initState() {
    super.initState();
    _workoutService.addListener(_onServiceUpdate);
    _selectDailyQuote();
    // If walk was running, resume timer
    if (_workoutService.isWalkRunning) {
      _startLocalWalkTimer();
    }
  }

  @override
  void dispose() {
    _workoutService.removeListener(_onServiceUpdate);
    _walkTimer?.cancel();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _selectDailyQuote() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year, 1, 1)).inDays;
    _quote = _quotes[dayOfYear % _quotes.length];
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 17) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }

  // Walk Timer Logic
  void _startLocalWalkTimer() {
    _walkTimer?.cancel();
    _walkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_workoutService.isWalkRunning) {
        _workoutService.updateWalkTimer(_workoutService.walkElapsedSeconds + 1);
      } else {
        timer.cancel();
      }
    });
  }

  void _toggleWalkTimer() {
    HapticFeedback.lightImpact();
    if (_workoutService.isWalkRunning) {
      _workoutService.setWalkRunning(false);
      _walkTimer?.cancel();
    } else {
      _workoutService.setWalkRunning(true);
      _startLocalWalkTimer();
    }
  }

  void _resetWalkTimer() {
    HapticFeedback.mediumImpact();
    _workoutService.resetWalkToday();
    _walkTimer?.cancel();
  }

  void _completeWalk() {
    HapticFeedback.mediumImpact();
    _workoutService.completeWalkToday();
    _walkTimer?.cancel();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).colorScheme.secondary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    final activePlan = _workoutService.activePlan;
    final int todayWeekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    final WorkoutDay? todayWorkout = activePlan?.days[todayWeekday];
    final bool isRestDay = todayWorkout == null || todayWorkout.isRestDay;
    final bool isCompleted = _workoutService.isTodayWorkoutCompleted;

    // Localized Tamil day names helper
    final List<String> weekdaysTamil = [
      "", "திங்கள் (Monday)", "செவ்வாய் (Tuesday)", "புதன் (Wednesday)",
      "வியாழன் (Thursday)", "வெள்ளி (Friday)", "சனி (Saturday)", "ஞாயிறு (Sunday)"
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Quote
          Text(
            "${_getGreeting()}, ${_workoutService.profileName} 👋",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _quote,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFA0A0A5),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          // Streak Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _workoutService.currentStreak > 0
                    ? accentColor.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.1),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Text(
                  _workoutService.currentStreak > 0 ? "🔥" : "💀",
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _workoutService.currentStreak > 0
                          ? "${_workoutService.currentStreak} DAY STREAK"
                          : "0 DAY STREAK",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: _workoutService.currentStreak > 0 ? accentColor : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _workoutService.currentStreak > 0
                          ? "Keep pushing! Consistency is progress."
                          : "Complete today's workout to start a streak!",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFA0A0A5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // TODAY'S WORKOUT SECTION
          const Text(
            "TODAY'S WORKOUT",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFFA0A0A5),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekdaysTamil[todayWeekday],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRestDay ? "Rest Day" : todayWorkout.workoutName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isRestDay ? Icons.airline_seat_flat_angled : Icons.fitness_center,
                      color: isRestDay ? Colors.grey : primaryColor,
                      size: 32,
                    ),
                  ],
                ),
                
                if (!isRestDay) ...[
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildWorkoutStat(
                        Icons.format_list_bulleted,
                        "${todayWorkout.exercises.length} Exercises",
                      ),
                      _buildWorkoutStat(
                        Icons.repeat,
                        "3 Sets Each",
                      ),
                      if (todayWorkout.walkingTargetMinutes > 0)
                        _buildWorkoutStat(
                          Icons.directions_walk,
                          "${todayWorkout.walkingTargetMinutes}m Walk",
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // START / COMPLETE BUTTON
                if (isCompleted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: accentColor, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              "TODAY'S WORKOUT COMPLETE",
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "Great work. Come back tomorrow.",
                          style: TextStyle(color: Color(0xFFA0A0A5), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else if (isRestDay)
                  ElevatedButton(
                    onPressed: widget.onNavigateToWorkouts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("VIEW WEEKLY PLAN"),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      HapticFeedback.heavyImpact();
                      // Open Workout Player
                      Navigator.of(context).pushNamed(
                        '/player',
                        arguments: {
                          'plan': activePlan,
                          'dayOfWeek': todayWeekday,
                        },
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow),
                        SizedBox(width: 10),
                        Text("START TODAY'S WORKOUT"),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // TODAY'S WALK SECTION
          const Text(
            "TODAY'S WALK",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: Color(0xFFA0A0A5),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                // Circular Timer Indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 75,
                      height: 75,
                      child: CircularProgressIndicator(
                        value: _workoutService.walkElapsedSeconds / _workoutService.walkTargetSeconds,
                        backgroundColor: Colors.white12,
                        color: accentColor,
                        strokeWidth: 6,
                      ),
                    ),
                    const Icon(Icons.directions_walk, color: Colors.white, size: 28),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _workoutService.isWalkCompletedToday 
                            ? "✅ WALK COMPLETED" 
                            : "🚶 ${_workoutService.walkTargetSeconds ~/ 60} MINUTE WALK",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _workoutService.isWalkCompletedToday ? accentColor : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDuration(_workoutService.walkElapsedSeconds),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Walking Controls
                      if (_workoutService.isWalkCompletedToday)
                        OutlinedButton(
                          onPressed: _resetWalkTimer,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            minimumSize: const Size(100, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text("Reset Walk"),
                        )
                      else
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: _toggleWalkTimer,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _workoutService.isWalkRunning ? Colors.white24 : accentColor,
                                foregroundColor: _workoutService.isWalkRunning ? Colors.white : Colors.black,
                                minimumSize: const Size(90, 36),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: Text(_workoutService.isWalkRunning ? "Pause" : "Start"),
                            ),
                            if (_workoutService.walkElapsedSeconds > 0) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: _completeWalk,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: accentColor),
                                  foregroundColor: accentColor,
                                  minimumSize: const Size(80, 36),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Text("Done"),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.refresh, color: Colors.grey),
                                onPressed: _resetWalkTimer,
                                tooltip: "Reset Timer",
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildWorkoutStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFA0A0A5)),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFFA0A0A5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
