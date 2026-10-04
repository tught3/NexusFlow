import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

// OAuth 딥링크 (app_links) — 앱 라이프타임 동안 유지되는 top-level 구독.
late final AppLinks _appLinks = AppLinks();
StreamSubscription<Uri>? _linkSubscription;

/// OAuth 콜백 딥링크 판별 — `nexusflow://auth-callback` (유닛 테스트 대상)
bool isAuthCallbackUri(Uri uri) =>
    uri.scheme == 'nexusflow' && uri.host == 'auth-callback';

/// 딥링크 처리 — OAuth 콜백이면 세션 교환.
/// 이미 처리된 링크 재처리 시 getSessionFromUrl이 에러 내지만 try/catch로 흡수.
Future<void> _handleDeepLink(Uri uri) async {
  if (!isAuthCallbackUri(uri)) return;
  try {
    await Supabase.instance.client.auth.getSessionFromUrl(uri);
  } catch (e) {
    debugPrint('OAuth 딥링크 처리 실패: $e');
  }
}

Future<void> _initDeepLinks() async {
  try {
    final initial = await _appLinks.getInitialLink();
    if (initial != null) await _handleDeepLink(initial);
  } catch (e) {
    debugPrint('초기 딥링크 확인 실패: $e');
  }
  _linkSubscription = _appLinks.uriLinkStream.listen(
    _handleDeepLink,
    onError: (Object e) => debugPrint('딥링크 스트림 오류: $e'),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  await _initDeepLinks();

  runApp(const ProviderScope(child: NexusFlowApp()));
}
