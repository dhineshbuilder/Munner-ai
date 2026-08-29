
class Exercise {
  final String id;
  final String name;
  final String emoji;
  final String type; // 'rep' or 'time'
  final int sets;
  final String reps; // e.g. "10-15" or "12"
  final int durationSeconds; // for time-based exercises
  final int restSeconds; // rest duration after each set
  final String instructions;
  final String equipment;

  Exercise({
    required this.id,
    required this.name,
    required this.emoji,
    required this.type,
    required this.sets,
    required this.reps,
    required this.durationSeconds,
    required this.restSeconds,
    this.instructions = "",
    this.equipment = "",
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'type': type,
      'sets': sets,
      'reps': reps,
      'durationSeconds': durationSeconds,
      'restSeconds': restSeconds,
      'instructions': instructions,
      'equipment': equipment,
    };
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      type: json['type'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as String,
      durationSeconds: json['durationSeconds'] as int,
      restSeconds: json['restSeconds'] as int,
      instructions: (json['instructions'] ?? "") as String,
      equipment: (json['equipment'] ?? "") as String,
    );
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? emoji,
    String? type,
    int? sets,
    String? reps,
    int? durationSeconds,
    int? restSeconds,
    String? instructions,
    String? equipment,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      type: type ?? this.type,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      instructions: instructions ?? this.instructions,
      equipment: equipment ?? this.equipment,
    );
  }
}

class WorkoutDay {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String workoutName; // e.g. "Full Body A" or "Rest"
  final List<Exercise> exercises;
  final int walkingTargetMinutes;

  WorkoutDay({
    required this.dayOfWeek,
    required this.workoutName,
    required this.exercises,
    required this.walkingTargetMinutes,
  });

  bool get isRestDay => exercises.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'workoutName': workoutName,
      'exercises': exercises.map((e) => e.toJson()).toList(),
      'walkingTargetMinutes': walkingTargetMinutes,
    };
  }

  factory WorkoutDay.fromJson(Map<String, dynamic> json) {
    var exercisesJson = json['exercises'] as List? ?? [];
    return WorkoutDay(
      dayOfWeek: json['dayOfWeek'] as int,
      workoutName: json['workoutName'] as String,
      exercises: exercisesJson.map((e) => Exercise.fromJson(e as Map<String, dynamic>)).toList(),
      walkingTargetMinutes: json['walkingTargetMinutes'] as int? ?? 0,
    );
  }

  WorkoutDay copyWith({
    int? dayOfWeek,
    String? workoutName,
    List<Exercise>? exercises,
    int? walkingTargetMinutes,
  }) {
    return WorkoutDay(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      workoutName: workoutName ?? this.workoutName,
      exercises: exercises ?? this.exercises,
      walkingTargetMinutes: walkingTargetMinutes ?? this.walkingTargetMinutes,
    );
  }
}

class WorkoutPlan {
  final String id;
  final String name;
  final bool isActive;
  final Map<int, WorkoutDay> days; // 1 = Monday, 7 = Sunday

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.isActive,
    required this.days,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isActive': isActive,
      'days': days.map((key, value) => MapEntry(key.toString(), value.toJson())),
    };
  }

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    var daysJson = json['days'] as Map<String, dynamic>? ?? {};
    Map<int, WorkoutDay> parsedDays = {};
    daysJson.forEach((key, value) {
      final parsedKey = int.tryParse(key);
      if (parsedKey != null) {
        parsedDays[parsedKey] = WorkoutDay.fromJson(value as Map<String, dynamic>);
      }
    });

    // Make sure we have entries for all days 1-7
    for (int i = 1; i <= 7; i++) {
      if (!parsedDays.containsKey(i)) {
        parsedDays[i] = WorkoutDay(
          dayOfWeek: i,
          workoutName: "Rest Day",
          exercises: [],
          walkingTargetMinutes: 0,
        );
      }
    }

    return WorkoutPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? false,
      days: parsedDays,
    );
  }

  WorkoutPlan copyWith({
    String? id,
    String? name,
    bool? isActive,
    Map<int, WorkoutDay>? days,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      days: days ?? this.days,
    );
  }
}

class WorkoutCompletion {
  final String id;
  final String date; // YYYY-MM-DD
  final String planId;
  final String workoutName;

  WorkoutCompletion({
    required this.id,
    required this.date,
    required this.planId,
    required this.workoutName,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'planId': planId,
      'workoutName': workoutName,
    };
  }

  factory WorkoutCompletion.fromJson(Map<String, dynamic> json) {
    return WorkoutCompletion(
      id: json['id'] as String,
      date: json['date'] as String,
      planId: json['planId'] as String,
      workoutName: json['workoutName'] as String,
    );
  }
}

class ActiveWorkoutSession {
  final String planId;
  final int dayOfWeek;
  final int currentExerciseIndex;
  final int currentSetIndex;
  final int elapsedSeconds;
  final bool isRestMode;
  final int restRemainingSeconds;

  ActiveWorkoutSession({
    required this.planId,
    required this.dayOfWeek,
    required this.currentExerciseIndex,
    required this.currentSetIndex,
    required this.elapsedSeconds,
    this.isRestMode = false,
    this.restRemainingSeconds = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'planId': planId,
      'dayOfWeek': dayOfWeek,
      'currentExerciseIndex': currentExerciseIndex,
      'currentSetIndex': currentSetIndex,
      'elapsedSeconds': elapsedSeconds,
      'isRestMode': isRestMode,
      'restRemainingSeconds': restRemainingSeconds,
    };
  }

  factory ActiveWorkoutSession.fromJson(Map<String, dynamic> json) {
    return ActiveWorkoutSession(
      planId: json['planId'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      currentExerciseIndex: json['currentExerciseIndex'] as int,
      currentSetIndex: json['currentSetIndex'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
      isRestMode: json['isRestMode'] as bool? ?? false,
      restRemainingSeconds: json['restRemainingSeconds'] as int? ?? 0,
    );
  }
}
