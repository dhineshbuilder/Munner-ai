import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import '../services/workout_service.dart';

class WorkoutPlayerScreen extends StatefulWidget {
  const WorkoutPlayerScreen({super.key});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  final WorkoutService _workoutService = WorkoutService();
  
  WorkoutPlan? _plan;
  int _dayOfWeek = 1;
  WorkoutDay? _workoutDay;
  List<Exercise> _exercises = [];

  // Player State
  int _currentExIdx = 0;
  int _currentSetIdx = 1; // 1-indexed for display
  int _elapsedWorkoutSeconds = 0;
  bool _isRestMode = false;
  int _restSecondsRemaining = 0;

  // Timers
  Timer? _workoutTimer;
  Timer? _exerciseCountdownTimer;
  Timer? _restTimer;

  // Active exercise countdown state (for time-based exercises)
  bool _isExCountdownRunning = false;
  int _exSecondsRemaining = 30;

  // Time calculations to prevent drift
  DateTime? _lastWorkoutTickTime;
  DateTime? _lastExCountdownTickTime;
  DateTime? _lastRestTickTime;

  bool _isInitialized = false;
  bool _isWorkoutComplete = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _plan = args['plan'] as WorkoutPlan?;
        _dayOfWeek = args['dayOfWeek'] as int? ?? 1;
        final bool resume = args['resume'] as bool? ?? false;

        if (_plan != null) {
          _workoutDay = _plan!.days[_dayOfWeek];
          _exercises = _workoutDay?.exercises ?? [];

          if (resume && _workoutService.activeSession != null) {
            final session = _workoutService.activeSession!;
            _currentExIdx = session.currentExerciseIndex;
            _currentSetIdx = session.currentSetIndex;
            _elapsedWorkoutSeconds = session.elapsedSeconds;
            _isRestMode = session.isRestMode;
            _restSecondsRemaining = session.restRemainingSeconds;
          }
        }
      }
      
      if (_exercises.isEmpty) {
        // Safe guard against empty list
        Navigator.pop(context);
        return;
      }

      _isInitialized = true;
      _startWorkoutTimer();

      // Initialize active exercise time if time-based
      final activeEx = _exercises[_currentExIdx];
      if (activeEx.type == "time") {
        _exSecondsRemaining = activeEx.durationSeconds;
      }

      if (_isRestMode) {
        _startRestTimer();
      } else if (activeEx.type == "time") {
        // Auto start time-based exercise
        _toggleExerciseCountdown(forceStart: true);
      }
    }
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _exerciseCountdownTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // Persistent session helper
  void _persistSessionState() {
    if (_isWorkoutComplete) return;
    
    final session = ActiveWorkoutSession(
      planId: _plan?.id ?? "",
      dayOfWeek: _dayOfWeek,
      currentExerciseIndex: _currentExIdx,
      currentSetIndex: _currentSetIdx,
      elapsedSeconds: _elapsedWorkoutSeconds,
      isRestMode: _isRestMode,
      restRemainingSeconds: _restSecondsRemaining,
    );
    _workoutService.saveActiveSession(session);
  }

  // General Workout stopwatch timer
  void _startWorkoutTimer() {
    _workoutTimer?.cancel();
    _lastWorkoutTickTime = DateTime.now();
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isRestMode && !_isWorkoutComplete) {
        final now = DateTime.now();
        final diff = now.difference(_lastWorkoutTickTime!).inSeconds;
        if (diff >= 1) {
          setState(() {
            _elapsedWorkoutSeconds += diff;
          });
          _lastWorkoutTickTime = now;
          _persistSessionState();
        }
      } else {
        _lastWorkoutTickTime = DateTime.now(); // reset anchor while paused/resting
      }
    });
  }

  // Time-based exercise countdown timer
  void _startExerciseCountdown() {
    _exerciseCountdownTimer?.cancel();
    _lastExCountdownTickTime = DateTime.now();
    _exerciseCountdownTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_isExCountdownRunning || _isRestMode || _isWorkoutComplete) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final diff = now.difference(_lastExCountdownTickTime!).inSeconds;
      if (diff >= 1) {
        setState(() {
          _exSecondsRemaining = (_exSecondsRemaining - diff).clamp(0, 9999);
          if (_exSecondsRemaining == 0) {
            _isExCountdownRunning = false;
            timer.cancel();
            _onSetCompleted();
          }
        });
        _lastExCountdownTickTime = now;
      }
    });
  }

  void _toggleExerciseCountdown({bool? forceStart}) {
    HapticFeedback.lightImpact();
    setState(() {
      _isExCountdownRunning = forceStart ?? !_isExCountdownRunning;
      if (_isExCountdownRunning) {
        _startExerciseCountdown();
      } else {
        _exerciseCountdownTimer?.cancel();
      }
    });
  }

  // Rest timer
  void _startRestTimer() {
    _restTimer?.cancel();
    _lastRestTickTime = DateTime.now();
    _restTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted || !_isRestMode || _isWorkoutComplete) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final diff = now.difference(_lastRestTickTime!).inSeconds;
      if (diff >= 1) {
        setState(() {
          _restSecondsRemaining = (_restSecondsRemaining - diff).clamp(0, 9999);
          if (_restSecondsRemaining == 0) {
            _isRestMode = false;
            timer.cancel();
            _goToNextSetOrExercise();
          }
        });
        _lastRestTickTime = now;
        _persistSessionState();
      }
    });
  }

  void _onSetCompleted() {
    HapticFeedback.mediumImpact();
    final activeEx = _exercises[_currentExIdx];

    // Cancel exercise countdown if running
    _isExCountdownRunning = false;
    _exerciseCountdownTimer?.cancel();

    if (activeEx.restSeconds > 0) {
      // Trigger rest timer mode
      setState(() {
        _isRestMode = true;
        _restSecondsRemaining = activeEx.restSeconds;
      });
      _startRestTimer();
      _persistSessionState();
    } else {
      // Go directly to next set/exercise
      _goToNextSetOrExercise();
    }
  }

  void _goToNextSetOrExercise() {
    final activeEx = _exercises[_currentExIdx];

    if (_currentSetIdx < activeEx.sets) {
      // Move to next set of the same exercise
      setState(() {
        _currentSetIdx++;
        if (activeEx.type == "time") {
          _exSecondsRemaining = activeEx.durationSeconds;
          _toggleExerciseCountdown(forceStart: true);
        }
      });
    } else {
      // Move to next exercise
      if (_currentExIdx < _exercises.length - 1) {
        setState(() {
          _currentExIdx++;
          _currentSetIdx = 1;
          final nextEx = _exercises[_currentExIdx];
          if (nextEx.type == "time") {
            _exSecondsRemaining = nextEx.durationSeconds;
            _toggleExerciseCountdown(forceStart: true);
          }
        });
      } else {
        // Last set of last exercise completed!
        _completeWorkout();
      }
    }
    _persistSessionState();
  }

  void _addRestTime() {
    HapticFeedback.lightImpact();
    setState(() {
      _restSecondsRemaining += 15;
    });
    _persistSessionState();
  }

  void _skipRest() {
    HapticFeedback.mediumImpact();
    _restTimer?.cancel();
    setState(() {
      _isRestMode = false;
      _restSecondsRemaining = 0;
    });
    _goToNextSetOrExercise();
  }

  void _skipExercise() {
    HapticFeedback.mediumImpact();
    
    // Stop timers
    _isExCountdownRunning = false;
    _exerciseCountdownTimer?.cancel();
    _restTimer?.cancel();
    
    setState(() {
      _isRestMode = false;
      if (_currentExIdx < _exercises.length - 1) {
        _currentExIdx++;
        _currentSetIdx = 1;
        final nextEx = _exercises[_currentExIdx];
        if (nextEx.type == "time") {
          _exSecondsRemaining = nextEx.durationSeconds;
          _toggleExerciseCountdown(forceStart: true);
        }
      } else {
        _completeWorkout();
      }
    });
    _persistSessionState();
  }

  Future<void> _completeWorkout() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isWorkoutComplete = true;
    });

    _workoutTimer?.cancel();
    _exerciseCountdownTimer?.cancel();
    _restTimer?.cancel();

    // Mark completion in service
    await _workoutService.completeWorkout(_plan?.id ?? "", _workoutDay?.workoutName ?? "");
  }

  String _formatElapsedTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<bool> _onWillPop() async {
    if (_isWorkoutComplete) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Exit Workout?"),
          content: const Text(
            "Your workout progress is saved automatically. You can resume this session later from the home screen.",
            style: TextStyle(color: Color(0xFFA0A0A5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Stay", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Exit", style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).colorScheme.secondary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isWorkoutComplete) {
      return _buildCompletionScreen(primaryColor, accentColor, surfaceColor);
    }

    final activeEx = _exercises[_currentExIdx];
    final double overallProgress = (_currentExIdx + (_currentSetIdx - 1) / activeEx.sets) / _exercises.length;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Main Workout layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Top stats row (Close, Progress counter, timer)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () async {
                            if (await _onWillPop()) {
                              if (mounted) Navigator.pop(context);
                            }
                          },
                        ),
                        Column(
                          children: [
                            Text(
                              "Exercise ${_currentExIdx + 1} of ${_exercises.length}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFA0A0A5),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Elapsed: ${_formatElapsedTime(_elapsedWorkoutSeconds)}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        // Skip Exercise Button
                        TextButton(
                          onPressed: _skipExercise,
                          child: const Text("SKIP EX", style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: overallProgress.clamp(0.0, 1.0),
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        minHeight: 6,
                      ),
                    ),
                    
                    const Spacer(),

                    // Active Exercise detail
                    Text(
                      activeEx.emoji,
                      style: const TextStyle(fontSize: 84),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      activeEx.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (activeEx.equipment.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          activeEx.equipment,
                          style: const TextStyle(color: Color(0xFFA0A0A5), fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 24),

                    // Set counter
                    Text(
                      "SET $_currentSetIdx OF ${activeEx.sets}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Target goal widget (Rep or Timer countdown)
                    if (activeEx.type == "rep")
                      Text(
                        "${activeEx.reps} REPS",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      Column(
                        children: [
                          Text(
                            _formatElapsedTime(_exSecondsRemaining),
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 12),
                          IconButton(
                            icon: Icon(
                              _isExCountdownRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                              size: 64,
                              color: _isExCountdownRunning ? Colors.white70 : accentColor,
                            ),
                            onPressed: () => _toggleExerciseCountdown(),
                          ),
                        ],
                      ),

                    if (activeEx.instructions.isNotEmpty) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          activeEx.instructions,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFA0A0A5),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],

                    const Spacer(),

                    // Action trigger
                    if (activeEx.type == "rep")
                      ElevatedButton(
                        onPressed: _onSetCompleted,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
                        child: const Text("✅ SET COMPLETE"),
                      )
                    else
                      OutlinedButton(
                        onPressed: _onSetCompleted,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white30),
                          foregroundColor: Colors.white70,
                        ),
                        child: const Text("Mark Set Done Early"),
                      ),
                  ],
                ),
              ),

              // Rest overlay countdown
              if (_isRestMode)
                Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  width: double.infinity,
                  height: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "REST",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _formatElapsedTime(_restSecondsRemaining),
                        style: const TextStyle(
                          fontSize: 84,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Next: ${_currentSetIdx < activeEx.sets ? '${activeEx.name} (Set ${_currentSetIdx + 1})' : (_currentExIdx < _exercises.length - 1 ? _exercises[_currentExIdx + 1].name : 'Finish Workout')}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFA0A0A5), fontSize: 16),
                      ),
                      const SizedBox(height: 48),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addRestTime,
                            icon: const Icon(Icons.add),
                            label: const Text("+15 SEC"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(130, 48),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: _skipRest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(130, 48),
                            ),
                            child: const Text("SKIP REST"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionScreen(Color primaryColor, Color accentColor, Color surfaceColor) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.check_circle_rounded, color: accentColor, size: 64),
              ),
              const SizedBox(height: 32),
              const Text(
                "🎉 WORKOUT COMPLETE!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Consistency is key. You're building a stronger, healthier version of yourself.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFA0A0A5), fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
              
              // Completion stats block
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildCompletionStat(
                      Icons.timer_outlined,
                      _formatElapsedTime(_elapsedWorkoutSeconds),
                      "Workout Duration",
                      accentColor,
                    ),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _buildCompletionStat(
                      Icons.local_fire_department,
                      _workoutService.currentStreak > 0 
                          ? "${_workoutService.currentStreak} Days" 
                          : "1 Day",
                      "Current Streak",
                      primaryColor,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.black,
                ),
                child: const Text("DONE", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionStat(IconData icon, String val, String title, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          val,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFFA0A0A5)),
        ),
      ],
    );
  }
}
