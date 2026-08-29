import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workout_service.dart';
import '../models/workout.dart';

class WorkoutsTab extends StatefulWidget {
  const WorkoutsTab({super.key});

  @override
  State<WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends State<WorkoutsTab> {
  final WorkoutService _workoutService = WorkoutService();

  @override
  void initState() {
    super.initState();
    _workoutService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _workoutService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _createPlanDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Create Workout Plan"),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Plan Name (e.g. My Weekly Plan)",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  HapticFeedback.mediumImpact();
                  
                  // Initialize blank 7 days map
                  final Map<int, WorkoutDay> days = {};
                  for (int i = 1; i <= 7; i++) {
                    days[i] = WorkoutDay(
                      dayOfWeek: i,
                      workoutName: "Rest Day",
                      exercises: [],
                      walkingTargetMinutes: 0,
                    );
                  }

                  final newPlan = WorkoutPlan(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text.trim(),
                    isActive: _workoutService.plans.isEmpty,
                    days: days,
                  );

                  _workoutService.addPlan(newPlan);
                  Navigator.pop(context);
                  
                  // Open detail designer right away
                  _openPlanDesigner(newPlan);
                }
              },
              child: Text("Create", style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeletePlan(WorkoutPlan plan) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Delete Plan?"),
          content: Text("Are you sure you want to delete '${plan.name}'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _workoutService.deletePlan(plan.id);
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  void _openPlanDesigner(WorkoutPlan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlanDesignerScreen(plan: plan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final accentColor = Theme.of(context).colorScheme.secondary;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "MY PLANS",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFFA0A0A5),
                ),
              ),
              TextButton.icon(
                onPressed: _createPlanDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Create Plan"),
                style: TextButton.styleFrom(
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_workoutService.plans.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Column(
                  children: [
                    const Icon(Icons.fitness_center_outlined, size: 48, color: Colors.white24),
                    const SizedBox(height: 16),
                    const Text(
                      "No workout plans configured.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _createPlanDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(180, 48),
                      ),
                      child: const Text("Create a Plan"),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _workoutService.plans.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final plan = _workoutService.plans[index];
                
                // Count working days
                final workingDaysCount = plan.days.values.where((d) => d.exercises.isNotEmpty).length;

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: plan.isActive 
                          ? primaryColor.withValues(alpha: 0.3) 
                          : Colors.transparent,
                      width: 1.5,
                    ),
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
                                Row(
                                  children: [
                                    if (plan.isActive) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          "ACTIVE PLAN",
                                          style: TextStyle(
                                            color: primaryColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Expanded(
                                      child: Text(
                                        plan.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "$workingDaysCount Days Configured",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFA0A0A5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Quick Edit & Delete Icons
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                onPressed: () => _openPlanDesigner(plan),
                                tooltip: "Edit Plan Structure",
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                                onPressed: () => _confirmDeletePlan(plan),
                                tooltip: "Delete Plan",
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          if (!plan.isActive)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _workoutService.setActivePlan(plan.id);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("Set as Active"),
                              ),
                            ),
                          if (plan.isActive)
                            Expanded(
                              child: Container(
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check, color: accentColor, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Active Routine",
                                      style: TextStyle(
                                        color: accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _openPlanDesigner(plan),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Design Plan"),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// NESTED ROUTINE DESIGNER SCREEN
class PlanDesignerScreen extends StatefulWidget {
  final WorkoutPlan plan;
  const PlanDesignerScreen({super.key, required this.plan});

  @override
  State<PlanDesignerScreen> createState() => _PlanDesignerScreenState();
}

class _PlanDesignerScreenState extends State<PlanDesignerScreen> {
  final WorkoutService _workoutService = WorkoutService();
  late WorkoutPlan _localPlan;

  final List<String> _weekdays = [
    "", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
  ];

  @override
  void initState() {
    super.initState();
    _localPlan = widget.plan;
    _workoutService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _workoutService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      try {
        setState(() {
          _localPlan = _workoutService.plans.firstWhere((p) => p.id == widget.plan.id);
        });
      } catch (_) {
        // Plan got deleted, pop screen
        Navigator.pop(context);
      }
    }
  }

  void _openDayBuilder(int dayOfWeek) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DayBuilderScreen(plan: _localPlan, dayOfWeek: dayOfWeek),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(_localPlan.name),
        actions: [
          if (!_localPlan.isActive)
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                _workoutService.setActivePlan(_localPlan.id);
              },
              child: const Text("MAKE ACTIVE", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 7,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final dayOfWeek = index + 1;
          final dayData = _localPlan.days[dayOfWeek]!;
          final isRest = dayData.exercises.isEmpty;

          return InkWell(
            onTap: () => _openDayBuilder(dayOfWeek),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _weekdays[dayOfWeek].toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: isRest ? Colors.grey : primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRest ? "Rest Day" : dayData.workoutName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (!isRest) ...[
                          const SizedBox(height: 6),
                          Text(
                            "${dayData.exercises.length} Exercises | 🚶 ${dayData.walkingTargetMinutes} min walk",
                            style: const TextStyle(fontSize: 13, color: Color(0xFFA0A0A5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// NESTED DAY BUILDER (EXERCISE AND WALK SETTINGS)
class DayBuilderScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final int dayOfWeek;
  const DayBuilderScreen({super.key, required this.plan, required this.dayOfWeek});

  @override
  State<DayBuilderScreen> createState() => _DayBuilderScreenState();
}

class _DayBuilderScreenState extends State<DayBuilderScreen> {
  final WorkoutService _workoutService = WorkoutService();
  final TextEditingController _routineNameController = TextEditingController();
  
  late WorkoutDay _dayData;

  final List<String> _weekdays = [
    "", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
  ];

  @override
  void initState() {
    super.initState();
    _dayData = widget.plan.days[widget.dayOfWeek]!;
    _routineNameController.text = _dayData.workoutName == "Rest Day" ? "" : _dayData.workoutName;
  }

  @override
  void dispose() {
    _routineNameController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final routineName = _routineNameController.text.trim().isEmpty 
        ? (_dayData.exercises.isEmpty ? "Rest Day" : "Workout Routine")
        : _routineNameController.text.trim();

    final updatedDay = _dayData.copyWith(workoutName: routineName);
    
    final Map<int, WorkoutDay> updatedDays = Map.from(widget.plan.days);
    updatedDays[widget.dayOfWeek] = updatedDay;

    final updatedPlan = widget.plan.copyWith(days: updatedDays);
    _workoutService.updatePlan(updatedPlan);
  }

  void _openExerciseEditor({Exercise? exercise}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return ExerciseEditorSheet(
          exercise: exercise,
          onSave: (savedExercise) {
            setState(() {
              final exercises = List<Exercise>.from(_dayData.exercises);
              if (exercise == null) {
                // Add new
                exercises.add(savedExercise);
              } else {
                // Update existing
                final idx = exercises.indexWhere((e) => e.id == exercise.id);
                if (idx != -1) exercises[idx] = savedExercise;
              }
              _dayData = _dayData.copyWith(exercises: exercises);
            });
            _saveChanges();
          },
        );
      },
    );
  }

  void _deleteExercise(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      final exercises = List<Exercise>.from(_dayData.exercises);
      exercises.removeWhere((e) => e.id == id);
      _dayData = _dayData.copyWith(exercises: exercises);
    });
    _saveChanges();
  }

  void _updateWalking(int minutes) {
    setState(() {
      _dayData = _dayData.copyWith(walkingTargetMinutes: minutes);
    });
    _saveChanges();
  }

  void _reorderExercises(int oldIndex, int newIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final exercises = List<Exercise>.from(_dayData.exercises);
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
      _dayData = _dayData.copyWith(exercises: exercises);
    });
    _saveChanges();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text("${_weekdays[widget.dayOfWeek]} Config"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Routine Name Input
            TextField(
              controller: _routineNameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Routine Name (e.g. Legs & Core, Push Day)",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _saveChanges(),
            ),
            const SizedBox(height: 24),

            // WALKING CONFIG CARD
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.directions_walk, color: Colors.grey),
                      SizedBox(width: 8),
                      Text(
                        "Walk Target",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Daily Walking Goal",
                        style: TextStyle(color: Color(0xFFA0A0A5)),
                      ),
                      DropdownButton<int>(
                        value: _dayData.walkingTargetMinutes,
                        dropdownColor: surfaceColor,
                        underline: const SizedBox(),
                        onChanged: (val) => _updateWalking(val ?? 0),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text("No Walk")),
                          DropdownMenuItem(value: 15, child: Text("15 minutes")),
                          DropdownMenuItem(value: 30, child: Text("30 minutes")),
                          DropdownMenuItem(value: 40, child: Text("40 minutes")),
                          DropdownMenuItem(value: 45, child: Text("45 minutes")),
                          DropdownMenuItem(value: 60, child: Text("60 minutes")),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // EXERCISES LIST HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "EXERCISES",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Color(0xFFA0A0A5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openExerciseEditor(),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text("Add Exercise"),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_dayData.exercises.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.fitness_center, size: 36, color: Colors.white24),
                    SizedBox(height: 12),
                    Text(
                      "No exercises scheduled for this day.\nRest Day.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              // REORDERABLE EXERCISES LIST
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _dayData.exercises.length,
                onReorder: _reorderExercises,
                itemBuilder: (context, index) {
                  final ex = _dayData.exercises[index];
                  return Container(
                    key: ValueKey(ex.id),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(ex.emoji, style: const TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ex.type == "rep" 
                                    ? "${ex.sets} sets x ${ex.reps} reps (Rest: ${ex.restSeconds}s)" 
                                    : "${ex.sets} sets x ${ex.durationSeconds}s (Rest: ${ex.restSeconds}s)",
                                style: const TextStyle(color: Color(0xFFA0A0A5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                          onPressed: () => _openExerciseEditor(exercise: ex),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          onPressed: () => _deleteExercise(ex.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// EXERCISE EDITOR BOTTOM SHEET
class ExerciseEditorSheet extends StatefulWidget {
  final Exercise? exercise;
  final Function(Exercise) onSave;
  const ExerciseEditorSheet({super.key, this.exercise, required this.onSave});

  @override
  State<ExerciseEditorSheet> createState() => _ExerciseEditorSheetState();
}

class _ExerciseEditorSheetState extends State<ExerciseEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();

  String _emoji = "💪";
  String _type = "rep"; // rep or time
  int _sets = 3;
  int _duration = 30; // seconds
  int _rest = 60; // seconds

  final List<String> _emojiOptions = ["💪", "🦵", "🏋️", "🏃", "🧱", "🧘", "🧗", "✨", "🚴"];

  @override
  void initState() {
    super.initState();
    if (widget.exercise != null) {
      final ex = widget.exercise!;
      _nameController.text = ex.name;
      _repsController.text = ex.reps;
      _instructionsController.text = ex.instructions;
      _equipmentController.text = ex.equipment;
      _emoji = ex.emoji;
      _type = ex.type;
      _sets = ex.sets;
      _duration = ex.durationSeconds;
      _rest = ex.restSeconds;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _repsController.dispose();
    _instructionsController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exercise == null ? "Add Exercise" : "Edit Exercise",
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 20),

              // Name input
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Exercise Name (e.g. Squat, Bench Press)",
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Please enter an exercise name";
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Emoji Selection Grid
              const Text("Select Icon", style: TextStyle(color: Color(0xFFA0A0A5), fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _emojiOptions.map((emo) {
                  final isSelected = emo == _emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _emoji = emo),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? primaryColor.withValues(alpha: 0.2) : Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Text(emo, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Exercise Type Toggles
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Rep-Based"),
                      selected: _type == "rep",
                      selectedColor: primaryColor.withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(color: _type == "rep" ? Colors.white : Colors.grey),
                      onSelected: (val) => setState(() => _type = "rep"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text("Time-Based"),
                      selected: _type == "time",
                      selectedColor: primaryColor.withValues(alpha: 0.3),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(color: _type == "time" ? Colors.white : Colors.grey),
                      onSelected: (val) => setState(() => _type = "time"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Config counters (Sets, Reps, Duration, Rest)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _sets,
                      decoration: const InputDecoration(labelText: "Sets"),
                      dropdownColor: surfaceColor,
                      items: List.generate(8, (i) => i + 1).map((sets) {
                        return DropdownMenuItem(value: sets, child: Text("$sets Sets"));
                      }).toList(),
                      onChanged: (val) => setState(() => _sets = val ?? 3),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  if (_type == "rep")
                    Expanded(
                      child: TextFormField(
                        controller: _repsController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: "Reps (e.g. 10-12)"),
                        validator: (val) {
                          if (_type == "rep" && (val == null || val.isEmpty)) {
                            return "Enter reps";
                          }
                          return null;
                        },
                      ),
                    )
                  else
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _duration,
                        decoration: const InputDecoration(labelText: "Duration"),
                        dropdownColor: surfaceColor,
                        items: [15, 20, 30, 40, 45, 60, 90, 120].map((dur) {
                          return DropdownMenuItem(value: dur, child: Text("$dur seconds"));
                        }).toList(),
                        onChanged: (val) => setState(() => _duration = val ?? 30),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Rest timer selector
              DropdownButtonFormField<int>(
                value: _rest,
                decoration: const InputDecoration(labelText: "Rest Timer Between Sets"),
                dropdownColor: surfaceColor,
                items: [0, 30, 45, 60, 90, 120, 150, 180].map((r) {
                  return DropdownMenuItem(value: r, child: Text(r == 0 ? "No Rest" : "$r seconds"));
                }).toList(),
                onChanged: (val) => setState(() => _rest = val ?? 60),
              ),
              const SizedBox(height: 16),

              // Instructions (Optional)
              TextFormField(
                controller: _instructionsController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Instructions (Optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Equipment (Optional)
              TextFormField(
                controller: _equipmentController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Equipment (e.g. Dumbbell, Mat) - Optional",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Save Action Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    HapticFeedback.mediumImpact();
                    final item = Exercise(
                      id: widget.exercise?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: _nameController.text.trim(),
                      emoji: _emoji,
                      type: _type,
                      sets: _sets,
                      reps: _type == "rep" ? _repsController.text.trim() : "",
                      durationSeconds: _type == "time" ? _duration : 0,
                      restSeconds: _rest,
                      instructions: _instructionsController.text.trim(),
                      equipment: _equipmentController.text.trim(),
                    );
                    widget.onSave(item);
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                child: const Text("Save Exercise"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
