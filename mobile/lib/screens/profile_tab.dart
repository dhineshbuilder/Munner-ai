import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/workout_service.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';

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
  bool _isPlayingAlarmTest = false;

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

  void _toggleAlarmEnabled(bool enabled) async {
    HapticFeedback.lightImpact();
    if (enabled) {
      await NotificationService().requestPermissions();
    }
    _workoutService.updateAlarmSettings(
      enabled: enabled,
      days: _workoutService.alarmDays.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : _workoutService.alarmDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
    );
  }

  void _toggleAlarmDay(int day) {
    HapticFeedback.lightImpact();
    final List<int> updatedDays = List<int>.from(_workoutService.alarmDays);
    if (updatedDays.contains(day)) {
      if (updatedDays.length > 1) {
        updatedDays.remove(day);
      }
    } else {
      updatedDays.add(day);
      updatedDays.sort();
    }
    _workoutService.updateAlarmSettings(
      enabled: true,
      days: updatedDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
    );
  }

  void _setAlarmPresetDays(List<int> presetDays) {
    HapticFeedback.lightImpact();
    _workoutService.updateAlarmSettings(
      enabled: true,
      days: presetDays,
      hour: _workoutService.alarmHour,
      minute: _workoutService.alarmMinute,
    );
  }

  void _toggleTestAlarmSound() async {
    HapticFeedback.mediumImpact();
    if (_isPlayingAlarmTest) {
      await AudioService().stop();
      if (mounted) setState(() => _isPlayingAlarmTest = false);
    } else {
      setState(() => _isPlayingAlarmTest = true);
      await AudioService().playAlarm();
      await NotificationService().showTestAlarmNotification();
      Future.delayed(const Duration(seconds: 6), () {
        if (mounted && _isPlayingAlarmTest) {
          setState(() => _isPlayingAlarmTest = false);
        }
      });
    }
  }

  Widget _buildPresetChip(String label, List<int> days, Color primaryColor) {
    final bool isMatching = _workoutService.alarmDays.length == days.length &&
        _workoutService.alarmDays.every((d) => days.contains(d));
    return InkWell(
      onTap: () => _setAlarmPresetDays(days),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isMatching ? primaryColor.withValues(alpha: 0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isMatching ? primaryColor : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isMatching ? FontWeight.bold : FontWeight.w500,
            color: isMatching ? primaryColor : Colors.white70,
          ),
        ),
      ),
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

          // WORKOUT REMINDER ALARM SECTION (Simplified & User-Friendly)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _workoutService.isAlarmEnabled 
                    ? primaryColor.withValues(alpha: 0.3) 
                    : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Switch Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _workoutService.isAlarmEnabled 
                                ? primaryColor.withValues(alpha: 0.15) 
                                : Colors.white10,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.alarm_on_rounded, 
                            color: _workoutService.isAlarmEnabled ? primaryColor : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Daily Workout Alarm",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _workoutService.isAlarmEnabled ? "Alarm is Active" : "Alarm is Turned Off",
                              style: TextStyle(
                                fontSize: 13,
                                color: _workoutService.isAlarmEnabled ? const Color(0xFF00E676) : const Color(0xFFA0A0A5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
                
                const Divider(color: Colors.white10, height: 28),
                
                // Prominent Big Time Picker Card
                InkWell(
                  onTap: () => _selectTime(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "REMINDER TIME",
                              style: TextStyle(
                                color: Color(0xFFA0A0A5),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alarmTimeStr,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: _workoutService.isAlarmEnabled ? Colors.white : Colors.grey,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: primaryColor),
                              const SizedBox(width: 6),
                              Text(
                                "Change",
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Day Presets Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "REPEAT",
                      style: TextStyle(
                        color: Color(0xFFA0A0A5),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPresetChip("Everyday", [1, 2, 3, 4, 5, 6, 7], primaryColor),
                        _buildPresetChip("Mon - Fri", [1, 2, 3, 4, 5], primaryColor),
                        _buildPresetChip("Mon - Sat", [1, 2, 3, 4, 5, 6], primaryColor),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Individual Day Selector Bubbles
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (index) {
                    final dayNum = index + 1; // 1 = Monday, 7 = Sunday
                    final isSelected = _workoutService.alarmDays.contains(dayNum);
                    return GestureDetector(
                      onTap: () => _toggleAlarmDay(dayNum),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? primaryColor : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          dayShortcuts[index],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // 🔊 Test Alarm Sound Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _toggleTestAlarmSound,
                    icon: Icon(
                      _isPlayingAlarmTest ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                      color: _isPlayingAlarmTest ? Colors.redAccent : primaryColor,
                      size: 20,
                    ),
                    label: Text(
                      _isPlayingAlarmTest ? "Stop Sound Preview" : "Test Alarm Sound (alarm.mp3)",
                      style: TextStyle(
                        color: _isPlayingAlarmTest ? Colors.redAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: _isPlayingAlarmTest ? Colors.redAccent : Colors.white12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
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
