import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/shell_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/account/account_list_screen.dart';
import 'screens/account/account_detail_screen.dart';
import 'screens/contact/contact_detail_screen.dart';
import 'screens/record/record_screen.dart';
import 'screens/record/confirm_screen.dart';
import 'screens/record/validation_screen.dart';
import 'screens/insight/insight_list_screen.dart';
import 'screens/insight/insight_detail_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/settings/permission_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/onboarding/mode_select_screen.dart';
import 'screens/onboarding/import_screen.dart';
import 'screens/onboarding/consent_screen.dart';
import 'screens/auth/login_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'services/detection_orchestrator.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final onboardingState = ref.watch(onboardingCompletedProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      // 온보딩 완료 여부 로드 전에는 판단하지 않는다 (초기 플리커 방지).
      if (onboardingState is AsyncLoading) {
        return null;
      }
      final isLoggedIn = authState.value != null;
      final onboardingCompleted = onboardingState.value ?? false;
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isAuth = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuth && !isOnboarding) {
        return '/auth/login';
      }
      if (isLoggedIn && isAuth) {
        return onboardingCompleted ? '/home' : '/onboarding';
      }
      if (isLoggedIn && !onboardingCompleted && !isOnboarding) {
        return '/onboarding';
      }
      return null;
    },
    routes: [
      // 온보딩
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
        routes: [
          GoRoute(
            path: 'consent',
            builder: (context, state) => const ConsentScreen(),
          ),
          GoRoute(
            path: 'mode',
            builder: (context, state) => const ModeSelectScreen(),
          ),
          GoRoute(
            path: 'import',
            builder: (context, state) => const ImportScreen(),
          ),
        ],
      ),

      // 인증
      GoRoute(
        path: '/auth/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // 메인 Shell (하단 탭)
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => ShellScreen(child: child),
        routes: [
          // 홈
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),

          // 거래처
          GoRoute(
            path: '/accounts',
            builder: (context, state) => const AccountListScreen(),
            routes: [
              GoRoute(
                path: ':accountId',
                builder: (context, state) => AccountDetailScreen(
                  accountId: state.pathParameters['accountId']!,
                ),
              ),
            ],
          ),

          // 담당자
          GoRoute(
            path: '/contacts/:contactId',
            builder: (context, state) => ContactDetailScreen(
              contactId: state.pathParameters['contactId']!,
            ),
          ),

          // 기록
          GoRoute(
            path: '/record',
            builder: (context, state) => const RecordScreen(),
          ),

          // 인사이트
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightListScreen(),
            routes: [
              GoRoute(
                path: ':insightId',
                builder: (context, state) => InsightDetailScreen(
                  insightId: state.pathParameters['insightId']!,
                ),
              ),
            ],
          ),

          // 설정
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'permissions',
                builder: (context, state) => const PermissionScreen(),
              ),
            ],
          ),
        ],
      ),

      // 모달 (Shell 밖)
      GoRoute(
        path: '/confirm',
        builder: (context, state) => ConfirmScreen(
          extractionId: state.uri.queryParameters['extractionId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/validation',
        builder: (context, state) => ValidationScreen(
          extractionId: state.uri.queryParameters['extractionId'] ?? '',
        ),
      ),
    ],
  );
});

class NexusFlowApp extends ConsumerStatefulWidget {
  const NexusFlowApp({super.key});

  @override
  ConsumerState<NexusFlowApp> createState() => _NexusFlowAppState();
}

class _NexusFlowAppState extends ConsumerState<NexusFlowApp> {
  /// 초기 진입/재로그인 시 1회 syncFlags를 보장하기 위한 마지막 동기화 인스턴스.
  DetectionOrchestrator? _lastSynced;

  /// 4종 감지 플래그 현재값을 오케스트레이터에 동기화.
  /// SharedPreferences 복원(detectFlagsInit)이 아직 안 됐으면 먼저 기다린 뒤
  /// StateProvider 값을 읽는다 — 재호출 시 FutureProvider 캐시로 즉시 통과.
  Future<void> _syncFlags() async {
    if (!mounted) return;
    try {
      await ref.read(detectFlagsInitProvider.future);
    } catch (_) {
      // 복원 실패 시 기본값(false)으로 진행 — 감지 기능 미기동은 안전한 방향이다.
    }
    if (!mounted) return;
    ref.read(detectionOrchestratorProvider)?.syncFlags(
          sms: ref.read(smsDetectEnabledProvider),
          screenshot: ref.read(screenshotDetectEnabledProvider),
          call: ref.read(callDetectEnabledProvider),
          kakao: ref.read(kakaoDetectEnabledProvider),
        );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // 감지 오케스트레이터: 플래그 변화 → syncFlags
    ref.listen<bool>(smsDetectEnabledProvider, (_, __) => unawaited(_syncFlags()));
    ref.listen<bool>(screenshotDetectEnabledProvider, (_, __) => unawaited(_syncFlags()));
    ref.listen<bool>(callDetectEnabledProvider, (_, __) => unawaited(_syncFlags()));
    ref.listen<bool>(kakaoDetectEnabledProvider, (_, __) => unawaited(_syncFlags()));

    // 로그아웃 시 오케스트레이터 정리 (provider의 onDispose가 dispose 실행).
    ref.listen<String?>(currentUserIdProvider, (prev, next) {
      if (prev != null && next == null) {
        _lastSynced = null;
      }
    });

    // 로그인 직후/초기 진입 시 1회 동기화 (build 중 side effect 방지를 위해
    // postFrame으로 실행).
    final orchestrator = ref.watch(detectionOrchestratorProvider);
    if (orchestrator != null && !identical(orchestrator, _lastSynced)) {
      _lastSynced = orchestrator;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_syncFlags()));
    }

    return MaterialApp.router(
      title: 'NexusFlow',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      routerConfig: router,
    );
  }
}
