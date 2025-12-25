import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  // Toggle to enable/disable ads globally
  static const bool areAdsEnabled = false;

  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  static String get bannerAdUnitId {
    if (kDebugMode) {
      if (Platform.isAndroid) {
        return 'ca-app-pub-3940256099942544/6300978111'; // Test Android Banner
      } else if (Platform.isIOS) {
        return 'ca-app-pub-3940256099942544/2934735716'; // Test iOS Banner
      }
    }
    return Platform.isAndroid
        ? 'YOUR_ANDROID_AD_UNIT_ID'
        : 'YOUR_IOS_AD_UNIT_ID';
  }

  static BannerAd createBannerAd({
    required Function(Ad) onAdLoaded,
    required Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad, error);
        },
      ),
    );
  }
}
