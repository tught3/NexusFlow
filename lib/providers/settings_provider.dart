import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final industryModeProvider = StateProvider<String>((ref) {
  return 'pharma'; // 기본값: 제약영업
});

final screenshotDetectEnabledProvider = StateProvider<bool>((ref) => false);
final smsDetectEnabledProvider = StateProvider<bool>((ref) => false);
final callDetectEnabledProvider = StateProvider<bool>((ref) => false);
final kakaoDetectEnabledProvider = StateProvider<bool>((ref) => false);
