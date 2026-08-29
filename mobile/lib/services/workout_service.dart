import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';

class WorkoutService extends ChangeNotifier {
  static final WorkoutService _instance = WorkoutService._internal();
  factory WorkoutService() => _instance;
  WorkoutService._internal();

  List<WorkoutPlan> _plans = [];
  List<WorkoutCompletion> _completions = [];
  ActiveWorkoutSession? _activeSession;
  
  // Walking timer state
  bool _isWalkRunning = false;
  int _walkElapsedSeconds = 0;
  final int _walkTargetSeconds = 1800; // 30 mins default
  bool _isWalkCompletedToday = false;

  // Profile data
  String _profileName = "Dhinesh";
  String _profilePhotoPath = "";
  
  // Alarm Settings
  bool _isAlarmEnabled = false;
  List<int> _alarmDays = [1, 2, 3, 4, 5]; // Mon-Fri
  int _alarmHour = 6;
  int _alarmMinute = 30;
  int _alarmReminderOffsetMinutes = 15; // 15 mins before

  // Getters
  List<WorkoutPlan> get plans => _plans;
  List<WorkoutCompletion> get completions => _completions;
  ActiveWorkoutSession? get activeSession => _activeSession;
  
  bool get isWalkRunning => _isWalkRunning;
  int get walkElapsedSeconds => _walkElapsedSeconds;
  int get walkTargetSeconds => _walkTargetSeconds;
  bool get isWalkCompletedToday => _isWalkCompletedToday;

  String get profileName => _profileName;
  String get profilePhotoPath => _profilePhotoPath;

  bool get isAlarmEnabled => _isAlarmEnabled;
  List<int> get alarmDays => _alarmDays;
  int get alarmHour => _alarmHour;
  int get alarmMinute => _alarmMinute;
  int get alarmReminderOffsetMinutes => _alarmReminderOffsetMinutes;

  WorkoutPlan? get activePlan {
    try {
      return _plans.firstWhere((p) => p.isActive);
    } catch (_) {
      if (_plans.isNotEmpty) {
        return _plans.first;
      }
      return null;
    }
  }

  // Load data from SharedPreferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load plans
    final String? plansJson = prefs.getString('munner_workout_plans');
    if (plansJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(plansJson);
        _plans = decoded.map((p) => WorkoutPlan.fromJson(p as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error loading plans: $e");
        _plans = [];
      }
    }
    
    // Seed default plan if empty
    if (_plans.isEmpty) {
      _seedDefaultPlan();
      await savePlans();
    }

    // 2. Load completions
    final String? completionsJson = prefs.getString('munner_workout_completions');
    if (completionsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(completionsJson);
        _completions = decoded.map((c) => WorkoutCompletion.fromJson(c as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Error loading completions: $e");
        _completions = [];
      }
    }

    // 3. Load active session
    final String? sessionJson = prefs.getString('munner_active_session');
    if (sessionJson != null) {
      try {
        _activeSession = ActiveWorkoutSession.fromJson(jsonDecode(sessionJson) as Map<String, dynamic>);
      } catch (_) {
        _activeSession = null;
      }
    }

    // 4. Load walking progress for today
    final String todayStr = _getTodayDateString();
    final String? lastWalkDate = prefs.getString('munner_last_walk_date');
    if (lastWalkDate == todayStr) {
      _isWalkCompletedToday = prefs.getBool('munner_walk_completed_today') ?? false;
      _walkElapsedSeconds = prefs.getInt('munner_walk_elapsed_seconds') ?? 0;
    } else {
      _isWalkCompletedToday = false;
      _walkElapsedSeconds = 0;
      await prefs.setString('munner_last_walk_date', todayStr);
      await prefs.setBool('munner_walk_completed_today', false);
      await prefs.setInt('munner_walk_elapsed_seconds', 0);
    }

    // 5. Load profile
    _profileName = prefs.getString('munner_profile_name') ?? "Dhinesh";
    _profilePhotoPath = prefs.getString('munner_profile_photo') ?? "";

    // 6. Load alarms
    _isAlarmEnabled = prefs.getBool('munner_alarm_enabled') ?? false;
    _alarmHour = prefs.getInt('munner_alarm_hour') ?? 6;
    _alarmMinute = prefs.getInt('munner_alarm_minute') ?? 30;
    _alarmReminderOffsetMinutes = prefs.getInt('munner_alarm_offset') ?? 15;
    final List<String>? daysList = prefs.getStringList('munner_alarm_days');
    if (daysList != null) {
      _alarmDays = daysList.map((d) => int.parse(d)).toList();
    }

    notifyListeners();
  }

  // Seed default plan
  void _seedDefaultPlan() {
    final monday = WorkoutDay(
      dayOfWeek: 1,
      workoutName: "Full Body A",
      walkingTargetMinutes: 30,
      exercises: [
        Exercise(
          id: "def-ex-1",
          name: "Push-ups",
          emoji: "💪",
          type: "rep",
          sets: 3,
          reps: "10-15",
          durationSeconds: 0,
          restSeconds: 60,
          instructions: "Keep your core tight and lower your chest to the floor.",
          equipment: "Bodyweight",
        ),
        Exercise(
          id: "def-ex-2",
          name: "Bodyweight Squats",
          emoji: "🦵",
          type: "rep",
          sets: 3,
          reps: "12-15",
          durationSeconds: 0,
          restSeconds: 60,
          instructions: "Squat down as if sitting in a chair, keeping knees behind toes.",
          equipment: "Bodyweight",
        ),
        Exercise(
          id: "def-ex-3",
          name: "Plank Hold",
          emoji: "🧱",
          type: "time",
          sets: 3,
          reps: "",
          durationSeconds: 40,
          restSeconds: 45,
          instructions: "Keep head, neck, and spine aligned in a straight line.",
          equipment: "Bodyweight",
        ),
      ],
    );

    final wednesday = WorkoutDay(
      dayOfWeek: 3,
      workoutName: "Full Body B",
      walkingTargetMinutes: 30,
      exercises: [
        Exercise(
          id: "def-ex-4",
          name: "Dumbbell Rows",
          emoji: "🏋️",
          type: "rep",
          sets: 3,
          reps: "10-12",
          durationSeconds: 0,
          restSeconds: 60,
          instructions: "Pull dumbbell toward your hip, keeping elbow close to your side.",
          equipment: "Dumbbells",
        ),
        Exercise(
          id: "def-ex-5",
          name: "Lunges",
          emoji: "🏃",
          type: "rep",
          sets: 3,
          reps: "10 each leg",
          durationSeconds: 0,
          restSeconds: 60,
          instructions: "Step forward and lower back knee toward the floor.",
          equipment: "Bodyweight",
        ),
        Exercise(
          id: "def-ex-6",
          name: "Jumping Jacks",
          emoji: "✨",
          type: "time",
          sets: 3,
          reps: "",
          durationSeconds: 45,
          restSeconds: 30,
          instructions: "Maintain a steady, energetic rhythm.",
          equipment: "Bodyweight",
        ),
      ],
    );

    final friday = WorkoutDay(
      dayOfWeek: 5,
      workoutName: "Full Body C",
      walkingTargetMinutes: 30,
      exercises: [
        Exercise(
          id: "def-ex-7",
          name: "Glute Bridges",
          emoji: "🍑",
          type: "rep",
          sets: 3,
          reps: "15",
          durationSeconds: 0,
          restSeconds: 45,
          instructions: "Squeeze glutes at the top of the bridge, hold for 1 second.",
          equipment: "Bodyweight",
        ),
        Exercise(
          id: "def-ex-8",
          name: "Mountain Climbers",
          emoji: "🧗",
          type: "time",
          sets: 3,
          reps: "",
          durationSeconds: 30,
          restSeconds: 45,
          instructions: "Drive knees toward chest quickly while maintaining a solid plank position.",
          equipment: "Bodyweight",
        ),
      ],
    );

    final defaultPlan = WorkoutPlan(
      id: "default-plan-1",
      name: "Default 3-Day Split",
      isActive: true,
      days: {
        1: monday,
        2: WorkoutDay(dayOfWeek: 2, workoutName: "Rest Day", exercises: [], walkingTargetMinutes: 0),
        3: wednesday,
        4: WorkoutDay(dayOfWeek: 4, workoutName: "Rest Day", exercises: [], walkingTargetMinutes: 0),
        5: friday,
        6: WorkoutDay(dayOfWeek: 6, workoutName: "Rest Day", exercises: [], walkingTargetMinutes: 0),
        7: WorkoutDay(dayOfWeek: 7, workoutName: "Rest Day", exercises: [], walkingTargetMinutes: 0),
      },
    );

    _plans = [defaultPlan];
  }

  // Save plans
  Future<void> savePlans() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_plans.map((p) => p.toJson()).toList());
    await prefs.setString('munner_workout_plans', encoded);
  }

  // Save completions
  Future<void> saveCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_completions.map((c) => c.toJson()).toList());
    await prefs.setString('munner_workout_completions', encoded);
  }

  // Add a new workout plan
  Future<void> addPlan(WorkoutPlan plan) async {
    if (plan.isActive) {
      // Deactivate others
      _plans = _plans.map((p) => p.copyWith(isActive: false)).toList();
    }
    _plans.add(plan);
    await savePlans();
    notifyListeners();
  }

  // Update an existing plan
  Future<void> updatePlan(WorkoutPlan plan) async {
    if (plan.isActive) {
      _plans = _plans.map((p) => p.id == plan.id ? plan : p.copyWith(isActive: false)).toList();
    } else {
      _plans = _plans.map((p) => p.id == plan.id ? plan : p).toList();
    }
    await savePlans();
    notifyListeners();
  }

  // Delete a plan
  Future<void> deletePlan(String planId) async {
    _plans.removeWhere((p) => p.id == planId);
    if (_plans.isNotEmpty && !_plans.any((p) => p.isActive)) {
      // Set the first remaining as active
      _plans[0] = _plans[0].copyWith(isActive: true);
    }
    await savePlans();
    notifyListeners();
  }

  // Set a plan as active
  Future<void> setActivePlan(String planId) async {
    _plans = _plans.map((p) => p.copyWith(isActive: p.id == planId)).toList();
    await savePlans();
    notifyListeners();
  }

  // Record workout completion
  Future<void> completeWorkout(String planId, String workoutName) async {
    final todayStr = _getTodayDateString();
    
    // Prevent duplicate completion records on the same day
    if (_completions.any((c) => c.date == todayStr)) {
      return;
    }

    final newCompletion = WorkoutCompletion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: todayStr,
      planId: planId,
      workoutName: workoutName,
    );

    _completions.add(newCompletion);
    await saveCompletions();
    
    // Clear active session since workout completed
    await clearActiveSession();
    notifyListeners();
  }

  // Walk state triggers
  void updateWalkTimer(int elapsedSeconds, {bool notify = true}) {
    _walkElapsedSeconds = elapsedSeconds;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('munner_walk_elapsed_seconds', elapsedSeconds);
    });
    if (notify) notifyListeners();
  }

  void setWalkRunning(bool running) {
    _isWalkRunning = running;
    notifyListeners();
  }

  Future<void> completeWalkToday() async {
    _isWalkCompletedToday = true;
    _isWalkRunning = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('munner_walk_completed_today', true);
    notifyListeners();
  }

  Future<void> resetWalkToday() async {
    _walkElapsedSeconds = 0;
    _isWalkCompletedToday = false;
    _isWalkRunning = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('munner_walk_completed_today', false);
    await prefs.setInt('munner_walk_elapsed_seconds', 0);
    notifyListeners();
  }

  // Profile management
  Future<void> updateProfile({required String name, required String photoPath}) async {
    _profileName = name;
    _profilePhotoPath = photoPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('munner_profile_name', name);
    await prefs.setString('munner_profile_photo', photoPath);
    notifyListeners();
  }

  // Alarm settings
  Future<void> updateAlarmSettings({
    required bool enabled,
    required List<int> days,
    required int hour,
    required int minute,
    required int offsetMinutes,
  }) async {
    _isAlarmEnabled = enabled;
    _alarmDays = days;
    _alarmHour = hour;
    _alarmMinute = minute;
    _alarmReminderOffsetMinutes = offsetMinutes;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('munner_alarm_enabled', enabled);
    await prefs.setInt('munner_alarm_hour', hour);
    await prefs.setInt('munner_alarm_minute', minute);
    await prefs.setInt('munner_alarm_offset', offsetMinutes);
    await prefs.setStringList('munner_alarm_days', days.map((d) => d.toString()).toList());
    
    notifyListeners();
  }

  // Active workout session recovery
  Future<void> saveActiveSession(ActiveWorkoutSession session) async {
    _activeSession = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('munner_active_session', jsonEncode(session.toJson()));
    notifyListeners();
  }

  Future<void> clearActiveSession() async {
    _activeSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('munner_active_session');
    notifyListeners();
  }

  // Reset all application data
  Future<void> resetAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    _plans = [];
    _completions = [];
    _activeSession = null;
    _isWalkRunning = false;
    _walkElapsedSeconds = 0;
    _isWalkCompletedToday = false;
    _profileName = "Dhinesh";
    _profilePhotoPath = "";
    _isAlarmEnabled = false;
    _alarmDays = [1, 2, 3, 4, 5];
    _alarmHour = 6;
    _alarmMinute = 30;
    _alarmReminderOffsetMinutes = 15;

    _seedDefaultPlan();
    await savePlans();
    notifyListeners();
  }

  // STREAK CALCULATION LOGIC
  int get currentStreak {
    if (_completions.isEmpty) {
      return 0;
    }

    final activePlan = this.activePlan;
    if (activePlan == null) {
      // If no active plan, compute simple consecutive days
      return _calculateSimpleConsecutiveDays();
    }

    // Sort completions in ascending order (earliest to latest)
    final sortedCompletions = List<WorkoutCompletion>.from(_completions);
    sortedCompletions.sort((a, b) => a.date.compareTo(b.date));

    final lastCompletionStr = sortedCompletions.last.date;
    final DateTime lastCompletionDate = DateTime.parse(lastCompletionStr);
    final DateTime today = DateTime.parse(_getTodayDateString());

    // 1. Verify if the streak is currently broken (i.e. did the user miss a required day since last completion?)
    DateTime checkDate = lastCompletionDate.add(const Duration(days: 1));
    while (checkDate.isBefore(today)) {
      final dayOfWeek = checkDate.weekday; // 1 = Monday, 7 = Sunday
      final scheduledDay = activePlan.days[dayOfWeek];
      
      // If a required workout day had exercises and was missed
      if (scheduledDay != null && scheduledDay.exercises.isNotEmpty) {
        final dateStr = _getDateString(checkDate);
        final completed = _completions.any((c) => c.date == dateStr);
        if (!completed) {
          // Required workout day was missed completely! Streak resets to 0.
          return 0;
        }
      }
      checkDate = checkDate.add(const Duration(days: 1));
    }

    // 2. The streak is alive. Let's count consecutive completed workout days going backward.
    int streakCount = 0;
    DateTime countDate = lastCompletionDate;
    
    while (true) {
      final dateStr = _getDateString(countDate);
      final hasCompleted = _completions.any((c) => c.date == dateStr);
      final dayOfWeek = countDate.weekday;
      final scheduledDay = activePlan.days[dayOfWeek];

      if (hasCompleted) {
        streakCount++;
      } else {
        // If it was a scheduled rest day (no exercises configured), we skip it and continue the streak!
        final isRestDay = scheduledDay == null || scheduledDay.exercises.isEmpty;
        if (!isRestDay) {
          // Encountered a scheduled workout day that they missed. Stop counting.
          break;
        }
      }

      // Go back one day
      countDate = countDate.subtract(const Duration(days: 1));

      // Guard check: don't loop forever if history is limited
      if (countDate.isBefore(DateTime.parse(sortedCompletions.first.date).subtract(const Duration(days: 7)))) {
        break;
      }
    }

    return streakCount;
  }

  // Calculate simple consecutive days completed (fallback)
  int _calculateSimpleConsecutiveDays() {
    final sortedCompletions = List<WorkoutCompletion>.from(_completions);
    sortedCompletions.sort((a, b) => b.date.compareTo(a.date)); // descending (newest first)

    final todayStr = _getTodayDateString();
    final yesterdayStr = _getDateString(DateTime.now().subtract(const Duration(days: 1)));

    // If last completion was not today and not yesterday, streak is broken
    final lastDate = sortedCompletions.first.date;
    if (lastDate != todayStr && lastDate != yesterdayStr) {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = DateTime.parse(lastDate);
    
    for (int i = 0; i < sortedCompletions.length; i++) {
      final targetStr = _getDateString(checkDate);
      final completed = sortedCompletions.any((c) => c.date == targetStr);
      if (completed) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  // Helper date tools
  String _getTodayDateString() {
    return _getDateString(DateTime.now());
  }

  String _getDateString(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return "$year-$month-$day";
  }

  // Check if today's workout has already been completed
  bool get isTodayWorkoutCompleted {
    final todayStr = _getTodayDateString();
    return _completions.any((c) => c.date == todayStr);
  }
}
