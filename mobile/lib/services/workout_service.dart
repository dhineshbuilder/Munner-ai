import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout.dart';
import 'audio_service.dart';
import 'notification_service.dart';

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
  List<int> _alarmDays = [1, 2, 3, 4, 5, 6, 7]; // Everyday by default
  int _alarmHour = 6;
  int _alarmMinute = 30;
  int _alarmReminderOffsetMinutes = 0;
  Timer? _alarmCheckTimer;
  String? _lastAlarmTriggeredKey;
  Function(int hour, int minute)? onAlarmTriggered;

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
    
    // Seed default plan if empty or upgrade from old 3-day split
    if (_plans.isEmpty || (_plans.length == 1 && _plans.first.name == "Default 3-Day Split")) {
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

    if (_isAlarmEnabled) {
      NotificationService().scheduleWeeklyWorkoutAlarms(
        hour: _alarmHour,
        minute: _alarmMinute,
        days: _alarmDays,
      );
    }

    notifyListeners();
  }

  // Seed default 7-day progressive plan with warm-ups
  void _seedDefaultPlan() {
    // MONDAY: Full Body A
    final monday = WorkoutDay(
      dayOfWeek: 1,
      workoutName: "Full Body A",
      walkingTargetMinutes: 30,
      exercises: [
        // Warm-up
        Exercise(id: "mon-w1", name: "March in place (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "Warm up with light, rhythmic marching.", equipment: "Bodyweight"),
        Exercise(id: "mon-w2", name: "Arm & Hip circles (Warm-up)", emoji: "🔄", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "Loosen shoulders and hip joints.", equipment: "Bodyweight"),
        Exercise(id: "mon-w3", name: "Bodyweight squats (Warm-up)", emoji: "🏋️", type: "rep", sets: 1, reps: "10", durationSeconds: 0, restSeconds: 20, instructions: "Easy warm-up squats.", equipment: "Bodyweight"),
        Exercise(id: "mon-w4", name: "Easy lunges (Warm-up)", emoji: "🦵", type: "rep", sets: 1, reps: "6 each leg", durationSeconds: 0, restSeconds: 30, instructions: "Gentle lunges to prepare knees and hips.", equipment: "Bodyweight"),
        // Main Workout
        Exercise(id: "mon-e1", name: "Squat", emoji: "🦵", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Keep chest up, control the movement.", equipment: "Bodyweight / Dumbbell"),
        Exercise(id: "mon-e2", name: "One-arm dumbbell row", emoji: "💪", type: "rep", sets: 3, reps: "10–15 each side", durationSeconds: 0, restSeconds: 60, instructions: "Pull dumbbell toward hip, squeeze your back.", equipment: "Dumbbells"),
        Exercise(id: "mon-e3", name: "Incline push-up", emoji: "🤸", type: "rep", sets: 3, reps: "8–15", durationSeconds: 0, restSeconds: 60, instructions: "Hands on elevated surface (bench or table).", equipment: "Elevated Surface"),
        Exercise(id: "mon-e4", name: "Dumbbell Romanian deadlift", emoji: "🏋️", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Hinge at hips, slight knee bend, flat back.", equipment: "Dumbbells"),
        Exercise(id: "mon-e5", name: "Glute bridge", emoji: "🍑", type: "rep", sets: 3, reps: "12–20", durationSeconds: 0, restSeconds: 60, instructions: "Squeeze glutes at top, 1 sec hold.", equipment: "Mat / Floor"),
        Exercise(id: "mon-e6", name: "Dead bug", emoji: "🧘", type: "rep", sets: 3, reps: "8–12 each side", durationSeconds: 0, restSeconds: 60, instructions: "Keep lower back pressed against floor.", equipment: "Mat / Floor"),
      ],
    );

    // TUESDAY: Upper Body + Walk
    final tuesday = WorkoutDay(
      dayOfWeek: 2,
      workoutName: "Upper Body + Walk",
      walkingTargetMinutes: 40,
      exercises: [
        // Warm-up
        Exercise(id: "tue-w1", name: "Marching & Arm Swings (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 120, restSeconds: 15, instructions: "Easy march with chest and arm swings.", equipment: "Bodyweight"),
        Exercise(id: "tue-w2", name: "Arm Circles & Shoulder Rolls (Warm-up)", emoji: "🔄", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 20, instructions: "Rotate shoulders and arms smoothly.", equipment: "Bodyweight"),
        // Main Workout
        Exercise(id: "tue-e1", name: "Incline Push-ups", emoji: "🤸", type: "rep", sets: 3, reps: "8–15", durationSeconds: 0, restSeconds: 60, instructions: "Control the descent, push firmly.", equipment: "Elevated Surface"),
        Exercise(id: "tue-e2", name: "One-arm Dumbbell Row", emoji: "🏋️", type: "rep", sets: 3, reps: "10–15 each side", durationSeconds: 0, restSeconds: 60, instructions: "Don't swing dumbbell, pull with control.", equipment: "Dumbbells"),
        Exercise(id: "tue-e3", name: "One-arm Shoulder Press", emoji: "💪", type: "rep", sets: 3, reps: "8–12 each side", durationSeconds: 0, restSeconds: 60, instructions: "Press upward without arching back.", equipment: "Dumbbells"),
        Exercise(id: "tue-e4", name: "Dumbbell Floor Press", emoji: "🏋️", type: "rep", sets: 3, reps: "10–15 each side", durationSeconds: 0, restSeconds: 60, instructions: "Elbows touch floor gently, press up.", equipment: "Dumbbells / Floor"),
        Exercise(id: "tue-e5", name: "Dumbbell Biceps Curl", emoji: "💪", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Keep elbows pinned to your sides.", equipment: "Dumbbells"),
        Exercise(id: "tue-e6", name: "Overhead Triceps Extension", emoji: "🔱", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Extend arms overhead, bend elbows back.", equipment: "Dumbbells"),
      ],
    );

    // WEDNESDAY: Low-Impact Cardio + Core
    final wednesday = WorkoutDay(
      dayOfWeek: 3,
      workoutName: "Low-Impact Cardio + Core",
      walkingTargetMinutes: 40,
      exercises: [
        // Warm-up
        Exercise(id: "wed-w1", name: "March in Place & Circles (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 120, restSeconds: 15, instructions: "March in place, arm and hip circles.", equipment: "Bodyweight"),
        Exercise(id: "wed-w2", name: "Bodyweight squats (Warm-up)", emoji: "🦵", type: "rep", sets: 1, reps: "10", durationSeconds: 0, restSeconds: 20, instructions: "Warm up legs.", equipment: "Bodyweight"),
        // Cardio Circuit (3 Rounds)
        Exercise(id: "wed-e1", name: "March in place", emoji: "🚶", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Cardio circuit interval.", equipment: "Bodyweight"),
        Exercise(id: "wed-e2", name: "Bodyweight squats", emoji: "🦵", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Continuous smooth tempo.", equipment: "Bodyweight"),
        Exercise(id: "wed-e3", name: "Low Step-ups", emoji: "🪜", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Stable low step or aerobic bench.", equipment: "Step / Platform"),
        Exercise(id: "wed-e4", name: "Incline push-ups", emoji: "🤸", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Paced repetitions.", equipment: "Elevated Surface"),
        Exercise(id: "wed-e5", name: "Dumbbell deadlift", emoji: "🏋️", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Hinge properly, flat back.", equipment: "Dumbbells"),
        Exercise(id: "wed-e6", name: "Standing knee raises", emoji: "🦵", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 20, instructions: "Alternate lifting knees toward chest.", equipment: "Bodyweight"),
        Exercise(id: "wed-e7", name: "One-arm dumbbell row", emoji: "💪", type: "time", sets: 3, reps: "", durationSeconds: 40, restSeconds: 30, instructions: "Pull with control.", equipment: "Dumbbells"),
        // Core
        Exercise(id: "wed-e8", name: "Bird Dog", emoji: "🐦", type: "rep", sets: 3, reps: "10 each side", durationSeconds: 0, restSeconds: 30, instructions: "Opposite arm and leg reach, keep core braced.", equipment: "Mat / Floor"),
        Exercise(id: "wed-e9", name: "Dead Bug", emoji: "🧘", type: "rep", sets: 3, reps: "10 each side", durationSeconds: 0, restSeconds: 30, instructions: "Lower back flat against floor.", equipment: "Mat / Floor"),
        Exercise(id: "wed-e10", name: "Plank", emoji: "🧱", type: "time", sets: 3, reps: "", durationSeconds: 30, restSeconds: 45, instructions: "Solid forearm plank position.", equipment: "Mat / Floor"),
      ],
    );

    // THURSDAY: Walk + Core + Mobility
    final thursday = WorkoutDay(
      dayOfWeek: 4,
      workoutName: "Walk + Core + Mobility",
      walkingTargetMinutes: 45,
      exercises: [
        // Warm-up
        Exercise(id: "thu-w1", name: "Easy March & Arm Circles (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 120, restSeconds: 15, instructions: "Gentle warm-up movements.", equipment: "Bodyweight"),
        // Core
        Exercise(id: "thu-e1", name: "Dead Bug", emoji: "🐞", type: "rep", sets: 3, reps: "10 each side", durationSeconds: 0, restSeconds: 45, instructions: "Controlled, not to failure.", equipment: "Mat / Floor"),
        Exercise(id: "thu-e2", name: "Bird Dog", emoji: "🐦", type: "rep", sets: 3, reps: "10 each side", durationSeconds: 0, restSeconds: 45, instructions: "Reach arm and opposite leg slowly.", equipment: "Mat / Floor"),
        Exercise(id: "thu-e3", name: "Plank", emoji: "🧱", type: "time", sets: 3, reps: "", durationSeconds: 30, restSeconds: 45, instructions: "Hold steady, breathe.", equipment: "Mat / Floor"),
        Exercise(id: "thu-e4", name: "Glute Bridge", emoji: "🍑", type: "rep", sets: 2, reps: "15", durationSeconds: 0, restSeconds: 45, instructions: "Squeeze glutes at top.", equipment: "Mat / Floor"),
        // Mobility
        Exercise(id: "thu-e5", name: "Hamstring & Quad Stretches", emoji: "🦵", type: "time", sets: 1, reps: "", durationSeconds: 90, restSeconds: 15, instructions: "Hold gentle leg stretches.", equipment: "Bodyweight"),
        Exercise(id: "thu-e6", name: "Hip & Back Mobility", emoji: "🧘", type: "time", sets: 1, reps: "", durationSeconds: 90, restSeconds: 0, instructions: "Gentle hip openers and spinal rotations.", equipment: "Bodyweight"),
      ],
    );

    // FRIDAY: Full Body + Upper Body
    final friday = WorkoutDay(
      dayOfWeek: 5,
      workoutName: "Full Body + Upper Body",
      walkingTargetMinutes: 30,
      exercises: [
        // Warm-up
        Exercise(id: "fri-w1", name: "March in place & Hip Circles (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 120, restSeconds: 15, instructions: "Warm up shoulders and hips.", equipment: "Bodyweight"),
        Exercise(id: "fri-w2", name: "Bodyweight squats & Lunges (Warm-up)", emoji: "🦵", type: "rep", sets: 1, reps: "10 squats, 6 lunges", durationSeconds: 0, restSeconds: 20, instructions: "Prepare legs and lower body.", equipment: "Bodyweight"),
        // Main Workout
        Exercise(id: "fri-e1", name: "Incline Push-ups", emoji: "🤸", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Good form, controlled tempo.", equipment: "Elevated Surface"),
        Exercise(id: "fri-e2", name: "One-arm Dumbbell Row", emoji: "🏋️", type: "rep", sets: 3, reps: "12–15 each side", durationSeconds: 0, restSeconds: 60, instructions: "Drive elbow back, don't swing dumbbell.", equipment: "Dumbbells"),
        Exercise(id: "fri-e3", name: "One-arm Shoulder Press", emoji: "💪", type: "rep", sets: 3, reps: "10–12 each side", durationSeconds: 0, restSeconds: 60, instructions: "Solid overhead press.", equipment: "Dumbbells"),
        Exercise(id: "fri-e4", name: "Goblet Squat", emoji: "🦵", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Hold dumbbell at chest level, squat deep.", equipment: "Dumbbells"),
        Exercise(id: "fri-e5", name: "Dumbbell Romanian Deadlift", emoji: "🏋️", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Hinge hips back, feel hamstrings stretch.", equipment: "Dumbbells"),
        Exercise(id: "fri-e6", name: "Dumbbell Biceps Curl", emoji: "💪", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Full curl range of motion.", equipment: "Dumbbells"),
        Exercise(id: "fri-e7", name: "Overhead Triceps Extension", emoji: "🔱", type: "rep", sets: 3, reps: "10–15", durationSeconds: 0, restSeconds: 60, instructions: "Keep elbows high and tight.", equipment: "Dumbbells"),
      ],
    );

    // SATURDAY: Full Body Conditioning + Long Walk
    final saturday = WorkoutDay(
      dayOfWeek: 6,
      workoutName: "Full Body Conditioning",
      walkingTargetMinutes: 60,
      exercises: [
        // Warm-up
        Exercise(id: "sat-w1", name: "March in place & Circles (Warm-up)", emoji: "🚶", type: "time", sets: 1, reps: "", durationSeconds: 120, restSeconds: 15, instructions: "General warm-up.", equipment: "Bodyweight"),
        Exercise(id: "sat-w2", name: "Squats & Reverse Lunges (Warm-up)", emoji: "🦵", type: "rep", sets: 1, reps: "8 squats, 6 lunges", durationSeconds: 0, restSeconds: 20, instructions: "Leg activation.", equipment: "Bodyweight"),
        // Full-Body Circuit (3 rounds)
        Exercise(id: "sat-e1", name: "Squat", emoji: "🦵", type: "rep", sets: 3, reps: "12", durationSeconds: 0, restSeconds: 45, instructions: "Circuit round - squat rhythmically.", equipment: "Bodyweight / Dumbbell"),
        Exercise(id: "sat-e2", name: "Incline Push-ups", emoji: "🤸", type: "rep", sets: 3, reps: "10", durationSeconds: 0, restSeconds: 45, instructions: "Keep torso straight.", equipment: "Elevated Surface"),
        Exercise(id: "sat-e3", name: "Dumbbell Deadlift", emoji: "🏋️", type: "rep", sets: 3, reps: "12", durationSeconds: 0, restSeconds: 45, instructions: "Strong back position.", equipment: "Dumbbells"),
        Exercise(id: "sat-e4", name: "One-arm Dumbbell Row", emoji: "💪", type: "rep", sets: 3, reps: "10/side", durationSeconds: 0, restSeconds: 45, instructions: "Clean pull.", equipment: "Dumbbells"),
        Exercise(id: "sat-e5", name: "Supported Reverse Lunge", emoji: "🦵", type: "rep", sets: 3, reps: "8/leg", durationSeconds: 0, restSeconds: 45, instructions: "Step back smoothly.", equipment: "Bodyweight"),
        Exercise(id: "sat-e6", name: "One-arm Shoulder Press", emoji: "🏋️", type: "rep", sets: 3, reps: "10/side", durationSeconds: 0, restSeconds: 45, instructions: "Press upward firmly.", equipment: "Dumbbells"),
        Exercise(id: "sat-e7", name: "Glute Bridge", emoji: "🍑", type: "rep", sets: 3, reps: "15", durationSeconds: 0, restSeconds: 45, instructions: "Bridge and squeeze glutes.", equipment: "Mat / Floor"),
        Exercise(id: "sat-e8", name: "March in Place", emoji: "🚶", type: "time", sets: 3, reps: "", durationSeconds: 60, restSeconds: 60, instructions: "Cooldown march between rounds.", equipment: "Bodyweight"),
      ],
    );

    // SUNDAY: Recovery & Mobility
    final sunday = WorkoutDay(
      dayOfWeek: 7,
      workoutName: "Recovery & Mobility",
      walkingTargetMinutes: 30,
      exercises: [
        Exercise(id: "sun-e1", name: "Hamstring stretch", emoji: "🦵", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "30 sec each side, breathe into the stretch.", equipment: "Mat / Floor"),
        Exercise(id: "sun-e2", name: "Quad stretch", emoji: "🦵", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "30 sec each side, gentle quad opening.", equipment: "Bodyweight"),
        Exercise(id: "sun-e3", name: "Calf stretch", emoji: "🦶", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "30 sec each side against a wall.", equipment: "Wall"),
        Exercise(id: "sun-e4", name: "Hip circles & Mobility", emoji: "🔄", type: "rep", sets: 1, reps: "10 each direction", durationSeconds: 0, restSeconds: 15, instructions: "Smooth circular hip rotations.", equipment: "Bodyweight"),
        Exercise(id: "sun-e5", name: "Shoulder circles & Chest stretch", emoji: "🙆", type: "time", sets: 1, reps: "", durationSeconds: 60, restSeconds: 15, instructions: "Open chest and shoulders gently.", equipment: "Bodyweight"),
        Exercise(id: "sun-e6", name: "Gentle back mobility (Cat-Cow)", emoji: "🧘", type: "time", sets: 1, reps: "", durationSeconds: 90, restSeconds: 0, instructions: "Slow spinal waves on all fours.", equipment: "Mat / Floor"),
      ],
    );

    final defaultPlan = WorkoutPlan(
      id: "munner-7day-progression",
      name: "Munner 7-Day Progression Plan",
      isActive: true,
      days: {
        1: monday,
        2: tuesday,
        3: wednesday,
        4: thursday,
        5: friday,
        6: saturday,
        7: sunday,
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
    int offsetMinutes = 0,
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
    
    // Sync with system background alarm scheduler
    if (enabled) {
      await NotificationService().scheduleWeeklyWorkoutAlarms(
        hour: hour,
        minute: minute,
        days: days,
      );
    } else {
      await NotificationService().cancelAllAlarms();
    }

    notifyListeners();
  }

  // Active alarm ticker
  void startAlarmTicker({Function(int hour, int minute)? onTrigger}) {
    if (onTrigger != null) {
      onAlarmTriggered = onTrigger;
    }
    _alarmCheckTimer?.cancel();
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isAlarmEnabled) return;
      final now = DateTime.now();
      final currentDay = now.weekday; // 1 = Monday, 7 = Sunday
      
      if (!_alarmDays.contains(currentDay)) return;
      
      final String timeKey = "${now.year}-${now.month}-${now.day}_${now.hour}:${now.minute}";
      if (now.hour == _alarmHour && now.minute == _alarmMinute) {
        if (_lastAlarmTriggeredKey != timeKey) {
          _lastAlarmTriggeredKey = timeKey;
          AudioService().playAlarm();
          onAlarmTriggered?.call(_alarmHour, _alarmMinute);
          notifyListeners();
        }
      }
    });
  }

  void stopAlarmTicker() {
    _alarmCheckTimer?.cancel();
    _alarmCheckTimer = null;
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
