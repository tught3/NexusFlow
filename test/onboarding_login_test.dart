// 로그인·온보딩 화면 위젯 테스트 — Supabase 미초기화 상태에서 렌더되어야 한다
// (AuthService는 이벤트 핸들러 내에서만 생성하므로 빌드 타임 크래시가 없다).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/screens/auth/login_screen.dart';
import 'package:nexusflow/screens/onboarding/consent_screen.dart';
import 'package:nexusflow/screens/onboarding/mode_select_screen.dart';

void main() {
  Widget wrap(Widget child) =>
      ProviderScope(child: MaterialApp(home: child));

  testWidgets('LoginScreen이 폼과 OAuth 버튼을 표시한다', (tester) async {
    await tester.pumpWidget(wrap(const LoginScreen()));

    expect(find.text('NexusFlow'), findsOneWidget);
    expect(find.text('이메일'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
    expect(find.text('Kakao로 시작하기'), findsOneWidget);
    expect(find.text('Naver로 시작하기'), findsOneWidget);
  });

  testWidgets('ModeSelectScreen이 업종 카드 3개를 표시한다', (tester) async {
    await tester.pumpWidget(wrap(const ModeSelectScreen()));

    expect(find.text('제약영업'), findsOneWidget);
    expect(find.text('보험영업'), findsOneWidget);
    expect(find.text('공통영업'), findsOneWidget);
  });

  testWidgets('ConsentScreen이 수집 채널 5개를 표시한다', (tester) async {
    await tester.pumpWidget(wrap(const ConsentScreen()));

    expect(find.text('음성 메모'), findsOneWidget);
    expect(find.text('스크린샷'), findsOneWidget);
    expect(find.text('SMS'), findsOneWidget);
    expect(find.text('카카오톡 알림'), findsOneWidget);
    expect(find.text('통화 녹음'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(5));
  });
}
