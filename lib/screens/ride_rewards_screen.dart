import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:project_taxi_with_ai/controllers/reward_controller.dart';
import 'package:project_taxi_with_ai/theme/kinetic_styles.dart';

// Theme-adaptive accent: Gold for dark, Blue for light
Color _rewardAccent(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFFFBF00)
      : const Color(0xFF1E88E5);
}

class RideRewardsScreen extends StatefulWidget {
  const RideRewardsScreen({super.key});

  @override
  State<RideRewardsScreen> createState() => _RideRewardsScreenState();
}

class _RideRewardsScreenState extends State<RideRewardsScreen> {
  late ConfettiController _confettiController;
  final RewardController _rewardController = Get.put(RewardController());

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = _rewardAccent(context);

    return Scaffold(
      backgroundColor: KineticStyles.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Ride Rewards',
          style: KineticStyles.headline(20, weight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          // Subtle accent dot in AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.emoji_events_rounded, color: accent, size: 26),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background ambient glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    accent.withValues(alpha: isDark ? 0.12 : 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          Obx(() {
            if (_rewardController.isLoading.value) {
              return Center(
                child: CircularProgressIndicator(color: accent),
              );
            }

            final reward = _rewardController.rewardStatus.value;
            final int rides = reward?.currentCycleRides ?? 0;
            final int cycles = reward?.completedCycles ?? 0;
            final double earned = reward?.totalRewardsEarned ?? 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // --- 3D Pie Chart Progress ---
                  _build3DPieSection(rides, accent),

                  const SizedBox(height: 40),

                  // --- Stats Grid ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          accent: accent,
                          title: 'Total Earned',
                          value: '₹${earned.toInt()}',
                          subtitle: 'This Month',
                          icon: Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          context: context,
                          accent: accent,
                          title: 'Cycles',
                          value: '$cycles/4',
                          subtitle: 'Completed',
                          icon: Icons.refresh_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // --- Milestone Info ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.flag_rounded, color: accent, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Next Milestone',
                              style: KineticStyles.label(12,
                                  color: accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rides >= 7
                              ? '🎉 Cycle Complete! ₹100 credited!'
                              : 'Complete ${7 - rides} more rides to earn ₹100!',
                          style: KineticStyles.body(16, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (rides / 7.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(alpha: 0.07),
                            color: accent,
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$rides / 7 rides',
                          style: KineticStyles.label(10,
                              color: KineticStyles.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- Terms & Conditions ---
                  _buildTermsSection(accent),

                  const SizedBox(height: 40),
                ],
              ),
            );
          }),

          // --- Confetti Overlay ---
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              shouldLoop: false,
              colors: [
                _rewardAccent(context),
                Colors.amber,
                Colors.orange,
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DPieSection(int rides, Color accent) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          width: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(200, 200),
                painter: Pie3DPainter(
                  progress: (rides / 7.0).clamp(0.0, 1.0),
                  accentColor: accent,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$rides/7',
                    style: KineticStyles.headline(40, weight: FontWeight.bold),
                  ),
                  Text(
                    'Rides Completed',
                    style: KineticStyles.label(10,
                        color: KineticStyles.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required Color accent,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: KineticStyles.headline(24, weight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: KineticStyles.body(14, weight: FontWeight.w500),
          ),
          Text(
            subtitle,
            style: KineticStyles.label(10, color: KineticStyles.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsSection(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How it works',
          style: KineticStyles.headline(18, weight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildTermItem(Icons.check_circle_outline_rounded,
            'Complete 7 rides to earn ₹100 instant wallet credit.', accent),
        _buildTermItem(Icons.update_rounded,
            'Limit of 4 rewards per month (Max ₹400).', accent),
        _buildTermItem(Icons.calendar_month_rounded,
            'All counters reset on the 1st of every month.', accent),
        _buildTermItem(Icons.info_outline_rounded,
            'Only successfully completed rides are counted.', accent),
      ],
    );
  }

  Widget _buildTermItem(IconData icon, String text, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent.withValues(alpha: 0.8)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: KineticStyles.body(14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class Pie3DPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  Pie3DPainter({
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const thickness = 25.0;

    // 1. Draw Depth (Bottom Layer)
    final depthPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(
        center + const Offset(0, 8), radius - thickness / 2, depthPaint);

    // 2. Draw Background Ring
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    canvas.drawCircle(center, radius - thickness / 2, bgPaint);

    // 3. Draw Progress Arc with accent gradient
    final Color lighterAccent = Color.lerp(accentColor, Colors.white, 0.3)!;
    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [accentColor, lighterAccent, accentColor],
        stops: const [0.0, 0.5, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - thickness / 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );

    // 4. Add Highlights on top for 3D effect
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant Pie3DPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.accentColor != accentColor;
}
