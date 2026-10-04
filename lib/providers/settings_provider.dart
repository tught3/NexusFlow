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

/// SharedPreferences 키: 온보딩 완료 여부
const String kOnboardingCompletedKey = 'onboarding_completed';

/// 온보딩 완료 여부 (라우터 redirect에서 참조)
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kOnboardingCompletedKey) ?? false;
});

/// 감지 플래그 SharedPreferences 키
const String kDetectScreenshotKey = 'detect_screenshot';
const String kDetectSmsKey = 'detect_sms';
const String kDetectCallKey = 'detect_call';
const String kDetectKakaoKey = 'detect_kakao';

/// 감지 플래그 복원 — 앱/화면 진입 시 1회 read해서
/// SharedPreferences 저장값으로 4종 StateProvider를 세팅한다.
/// (StateProvider.overrideWith는 앱 최상단에서만 가능하므로 init 프로바이더 방식)
final detectFlagsInitProvider = FutureProvider<void>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  ref.read(screenshotDetectEnabledProvider.notifier).state =
      prefs.getBool(kDetectScreenshotKey) ?? false;
  ref.read(smsDetectEnabledProvider.notifier).state =
      prefs.getBool(kDetectSmsKey) ?? false;
  ref.read(callDetectEnabledProvider.notifier).state =
      prefs.getBool(kDetectCallKey) ?? false;
  ref.read(kakaoDetectEnabledProvider.notifier).state =
      prefs.getBool(kDetectKakaoKey) ?? false;
});
