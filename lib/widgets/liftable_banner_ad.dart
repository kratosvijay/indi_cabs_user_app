import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:project_taxi_with_ai/services/ad_service.dart';

class LiftableBannerAd extends StatefulWidget {
  const LiftableBannerAd({super.key});

  @override
  State<LiftableBannerAd> createState() => _LiftableBannerAdState();
}

class _LiftableBannerAdState extends State<LiftableBannerAd> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  bool _isExpanded = false;

  // Constants
  static const double _collapsedHeight = 30.0;
  static const double _expandedHeight =
      80.0; // AdSize.banner height (50) + handle (30)

  @override
  void initState() {
    super.initState();
    if (AdService.areAdsEnabled) {
      _loadAd();
    }
  }

  void _loadAd() {
    _bannerAd = AdService.createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() {
            _isAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) {
          setState(() {
            _isAdLoaded = false;
          });
        }
        ad.dispose();
      },
    )..load();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdService.areAdsEnabled || !_isAdLoaded) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < 0) {
          // Swipe Up
          if (!_isExpanded) _toggleExpand();
        } else if (details.primaryVelocity! > 0) {
          // Swipe Down
          if (_isExpanded) _toggleExpand();
        }
      },
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _isExpanded ? _expandedHeight : _collapsedHeight,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle / Indicator
            Container(
              height: _collapsedHeight,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!_isExpanded)
                    Text(
                      "Provided by AdMob",
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                      ),
                    ),
                ],
              ),
            ),
            // Expanded Content (The Ad)
            if (_isAdLoaded && _bannerAd != null)
              Expanded(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
