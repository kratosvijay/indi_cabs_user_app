import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';
import 'package:project_taxi_with_ai/app_colors.dart';
import 'package:get/get.dart';

/// A screen to pick a future date and time for a ride.
/// Returns a DateTime object if saved, otherwise null.
class SchedulePickerScreen extends StatefulWidget {
  const SchedulePickerScreen({super.key});

  @override
  State<SchedulePickerScreen> createState() => _SchedulePickerScreenState();
}

class _SchedulePickerScreenState extends State<SchedulePickerScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    // Initialize to 1 hour from now
    final now = DateTime.now().add(const Duration(hours: 1));
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(
      hour: now.hour,
      minute: (now.minute / 15).ceil() * 15 % 60,
    ); // Snap to next 15 min
    _adjustForMinimumTime();
  }

  DateTime get _selectedDateTime {
    return _selectedDate.add(
      Duration(hours: _selectedTime.hour, minutes: _selectedTime.minute),
    );
  }

  void _adjustForMinimumTime() {
    final now = DateTime.now().add(
      const Duration(minutes: 30),
    ); // Must be at least 30 min in future
    if (_selectedDateTime.isBefore(now)) {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(
        const Duration(days: 30),
      ), // Can book up to 30 days in advance
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.grey[900]!,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: Colors.black87,
                  ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
        _adjustForMinimumTime(); // Check if time needs to be adjusted
      });
    }
  }

  Future<void> _pickTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: isDark
                  ? ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: Colors.grey[900]!,
                      onSurface: Colors.white,
                    )
                  : ColorScheme.light(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      onSurface: Colors.black87,
                    ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (pickedTime != null) {
      setState(() {
        _selectedTime = pickedTime;
        _adjustForMinimumTime(); // Check if time is valid
      });
    }
  }

  void _saveSchedule() {
    final now = DateTime.now().add(
      const Duration(minutes: 29),
    ); // 30 min buffer
    if (_selectedDateTime.isBefore(now)) {
      displaySnackBar(
        context,
        "Scheduled time must be at least 30 minutes from now.",
      );
      return;
    }
    // Return the selected DateTime
    Get.back(result: _selectedDateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: const ProAppBar(titleText: "Schedule Your Ride"),
      body: FadeInSlide(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Select a pickup date and time:",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // --- Date Picker Card ---
              _buildSelectionCard(
                context,
                icon: Icons.calendar_today,
                title: "Date",
                value: DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                onTap: _pickDate,
                isDark: isDark,
                cardColor: cardColor!,
                textColor: textColor,
              ),
              const SizedBox(height: 20),

              // --- Time Picker Card ---
              _buildSelectionCard(
                context,
                icon: Icons.access_time,
                title: "Time",
                value: _selectedTime.format(context),
                onTap: _pickTime,
                isDark: isDark,
                cardColor: cardColor,
                textColor: textColor,
              ),

              const Spacer(),

              // --- Save Button ---
              ProButton(
                text: "Save Schedule",
                onPressed: _saveSchedule,
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 20),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
