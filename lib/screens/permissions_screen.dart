import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/screens/splash_screen.dart'; // To navigate back to Splash/Init logic
import 'package:project_taxi_with_ai/app_colors.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _contactsGranted = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when app resumes, in case user changed them in settings
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final locStatus = await Permission.location.status;
    final notifStatus = await Permission.notification.status;
    final contactStatus = await Permission.contacts.status;

    if (mounted) {
      setState(() {
        _locationGranted = locStatus.isGranted;
        _notificationGranted = notifStatus.isGranted;
        _contactsGranted = contactStatus.isGranted;
        _isChecking = false;
      });
    }

    if (_locationGranted && _notificationGranted && _contactsGranted) {
      _proceed();
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    await permission.request();
    _checkPermissions();
  }

  Future<void> _requestAll() async {
    await [
      Permission.location,
      Permission.notification,
      Permission.contacts,
    ].request();
    _checkPermissions();
  }

  void _proceed() {
    // Navigate back to Splash Screen or re-trigger initialization
    Get.offAll(() => const SplashScreen());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isChecking) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Icon(
                Icons.verified_user_outlined,
                size: 80,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "Permissions Required",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "To provide the best experience, we need access to the following:",
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              _buildPermissionTile(
                icon: Icons.location_on_outlined,
                title: "Location",
                description: "To find rides near you and track your trip.",
                isGranted: _locationGranted,
                onTap: () => _requestPermission(Permission.location),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                icon: Icons.notifications_outlined,
                title: "Notifications",
                description: "To update you on your ride status.",
                isGranted: _notificationGranted,
                onTap: () => _requestPermission(Permission.notification),
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                icon: Icons.contacts_outlined,
                title: "Contacts",
                description: "To allow booking rides for friends.",
                isGranted: _contactsGranted,
                onTap: () => _requestPermission(Permission.contacts),
                isDark: isDark,
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _requestAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Allow All",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGranted
              ? Colors.green.withValues(alpha: 0.5)
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isGranted
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isGranted
                ? Colors.green
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: isGranted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text("Allow"),
              ),
      ),
    );
  }
}
