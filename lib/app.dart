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

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isOnboarding = state.matchedLocation.startsWith('/onboarding');
      final isAuth = state.matchedLocation.startsWith('/auth');

      if (!isLoggedIn && !isAuth && !isOnboarding) {
        return '/auth/login';
      }
      if (isLoggedIn && isAuth) {
        return '/home';
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

class NexusFlowApp extends ConsumerWidget {
  const NexusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

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
