import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workout_service.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final WorkoutService _workoutService = WorkoutService();
  final TextEditingController _nameController = TextEditingController();

  // Settings mock toggles (persisted locally inside app settings or mock flags)
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _notificationsEnabled = true;

  final List<String> _avatars = ["🏃‍♂️", "🏃‍♀️", "🏋️‍♂️", "🏋️‍♀️", "💪", "⚡", "🧘‍♂️", "🧘‍♀️"];
  String _selectedAvatar = "💪";

  @override
  void initState() {
    super.initState();
    _nameController.text = _workoutService.profileName;
    _selectedAvatar = _workoutService.profilePhotoPath.isNotEmpty 
        ? _workoutService.profilePhotoPath 
        : "💪";
    _workoutService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _workoutService.removeListener(_onServiceUpdate);
    _nameController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {
        _nameController.text = _workoutService.profileName;
        _selectedAvatar = _workoutService.profilePhotoPath.isNotEmpty 
            ? _workoutService.profilePhotoPath 
            : "💪";
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _workoutService.alarmHour,
        minute: _workoutService.alarmMinute,
      ),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      HapticFeedback.lightImpact();
      _workoutService.updateAlarmSettings(
        enabled: _workoutService.isAlarmEnabled,
        days: _workoutService.alarmDays,
        hour: picked.hour,
        minute: picked.minute,
        offsetMinutes: _workoutService.alarmReminderOffsetMinutes,
      );
    }
  }

  void _toggleAlarmEnabled(bool enabled) {
    HapticFeedback.lightImpact();
    _workoutService.updateAlarmSettings(
      enabled: enabled,
      days: _workoutService.alarmDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
      offsetMinutes: _workoutService.alarmReminderOffsetMinutes,
    );
  }

  void _toggleAlarmDay(int day) {
    HapticFeedback.lightImpact();
    final List<int> updatedDays = List<int>.from(_workoutService.alarmDays);
    if (updatedDays.contains(day)) {
      updatedDays.remove(day);
    } else {
      updatedDays.add(day);
    }
    _workoutService.updateAlarmSettings(
      enabled: _workoutService.isAlarmEnabled,
      days: updatedDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
      offsetMinutes: _workoutService.alarmReminderOffsetMinutes,
    );
  }

  void _updateAlarmOffset(int offset) {
    HapticFeedback.lightImpact();
    _workoutService.updateAlarmSettings(
      enabled: _workoutService.isAlarmEnabled,
      days: _workoutService.alarmDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
      offsetMinutes: offset,
    );
  }

  void _editNameDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _workoutService.profileName);
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Edit Name"),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Enter name",
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
                  _workoutService.updateProfile(
                    name: controller.text.trim(),
                    photoPath: _selectedAvatar,
                  );
                  Navigator.pop(context);
                }
              },
              child: Text("Save", style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        );
      },
    );
  }

  void _changeAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text("Choose Avatar"),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _avatars.map((avatar) {
              final isSelected = avatar == _selectedAvatar;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _workoutService.updateProfile(
                    name: _workoutService.profileName,
                    photoPath: avatar,
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(avatar, style: const TextStyle(fontSize: 26)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _confirmResetData() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text("Reset All Data?"),
            ],
          ),
          content: const Text(
            "This will delete all your custom workout plans, history, walk records, and streaks. This cannot be undone.",
            style: TextStyle(color: Color(0xFFA0A0A5)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                final nav = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(dialogContext);
                await _workoutService.resetAllData();
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text("Application data has been reset.")),
                );
              },
              child: const Text("Reset Everything", style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? "PM" : "AM";
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return "$displayHour:$displayMinute $period";
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final alarmTimeStr = _formatTime(_workoutService.alarmHour, _workoutService.alarmMinute);

    final List<String> dayShortcuts = ["M", "T", "W", "T", "F", "S", "S"];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _changeAvatarDialog,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _selectedAvatar,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 12, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _workoutService.profileName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Level: Progression Builder",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFA0A0A5),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.grey, size: 28),
                  onPressed: _editNameDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // WORKOUT REMINDER ALARM SECTION
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.alarm, color: Colors.white70),
                        SizedBox(width: 12),
                        Text(
                          "Workout Reminder",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _workoutService.isAlarmEnabled,
                      activeThumbColor: primaryColor,
                      onChanged: _toggleAlarmEnabled,
                    ),
                  ],
                ),
                const Divider(color: Colors.white10, height: 24),
                
                // Alarm Time Selector
                GestureDetector(
                  onTap: _workoutService.isAlarmEnabled ? () => _selectTime(context) : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Start Time",
                        style: TextStyle(color: Color(0xFFA0A0A5)),
                      ),
                      Text(
                        alarmTimeStr,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _workoutService.isAlarmEnabled ? Colors.white : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Choose Days
                const Text(
                  "Choose Days",
                  style: TextStyle(color: Color(0xFFA0A0A5), fontSize: 13),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final dayNum = index + 1; // 1 = Monday, 7 = Sunday
                    final isSelected = _workoutService.alarmDays.contains(dayNum);
                    return GestureDetector(
                      onTap: _workoutService.isAlarmEnabled ? () => _toggleAlarmDay(dayNum) : null,
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected && _workoutService.isAlarmEnabled 
                              ? primaryColor 
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          dayShortcuts[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected && _workoutService.isAlarmEnabled 
                                ? Colors.white 
                                : Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Remind offset dropdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Remind me",
                      style: TextStyle(color: Color(0xFFA0A0A5)),
                    ),
                    DropdownButton<int>(
                      value: _workoutService.alarmReminderOffsetMinutes,
                      dropdownColor: surfaceColor,
                      underline: const SizedBox(),
                      onChanged: _workoutService.isAlarmEnabled 
                          ? (val) => _updateAlarmOffset(val ?? 15) 
                          : null,
                      items: const [
                        DropdownMenuItem(value: 5, child: Text("5 minutes before")),
                        DropdownMenuItem(value: 10, child: Text("10 minutes before")),
                        DropdownMenuItem(value: 15, child: Text("15 minutes before")),
                        DropdownMenuItem(value: 30, child: Text("30 minutes before")),
                        DropdownMenuItem(value: 60, child: Text("60 minutes before")),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // PREFERENCES / TOGGLES
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _buildToggleRow(
                  Icons.notifications_active_outlined,
                  "Push Notifications",
                  _notificationsEnabled,
                  (val) => setState(() => _notificationsEnabled = val),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildToggleRow(
                  Icons.volume_up_outlined,
                  "Sound effects",
                  _soundEnabled,
                  (val) => setState(() => _soundEnabled = val),
                ),
                const Divider(color: Colors.white10, height: 1),
                _buildToggleRow(
                  Icons.vibration,
                  "Vibration",
                  _vibrationEnabled,
                  (val) => setState(() => _vibrationEnabled = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // RESET / DATA DELETION
          OutlinedButton(
            onPressed: _confirmResetData,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent, width: 1.5),
              foregroundColor: Colors.redAccent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever),
                SizedBox(width: 8),
                Text("Reset All Data", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildToggleRow(IconData icon, String text, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFA0A0A5), size: 22),
            const SizedBox(width: 14),
            Text(
              text,
              style: const TextStyle(fontSize: 15, color: Colors.white),
            ),
          ],
        ),
        Switch(
          value: value,
          activeThumbColor: Theme.of(context).primaryColor,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            onChanged(val);
          },
        ),
      ],
    );
  }
}
