// 설정 화면 위젯 테스트 — Supabase/플랫폼 채널 미초기화 상태에서 렌더되어야 한다
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexusflow/providers/settings_provider.dart';
import 'package:nexusflow/screens/settings/permission_screen.dart';
import 'package:nexusflow/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) => ProviderScope(child: MaterialApp(home: child));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsScreen', () {
    testWidgets('렌더 스모크: 업종/감지/앱 정보 섹션 표시', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      // 업종 모드: 기본값 제약영업
      expect(find.text('제약영업'), findsOneWidget);
      // 감지 섹션: 스위치 4개
      expect(find.byType(SwitchListTile), findsNWidgets(4));

      // 앱 정보 (ListView 하단 — 스크롤 후 확인)
      await tester.scrollUntilVisible(
        find.text('말했더니 알아서 정리됨'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('NexusFlow'), findsOneWidget);
      expect(find.text('0.1.0 — 1차 배포 전'), findsOneWidget);
      expect(find.text('말했더니 알아서 정리됨'), findsOneWidget);
      // 온보딩/권한 진입 타일
      expect(find.text('온보딩 다시 보기'), findsOneWidget);
      expect(find.text('권한 설정'), findsOneWidget);
    });

    testWidgets('업종 모드 탭 → 시트에서 보험영업 선택 → provider 변경', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('mode_section')));
      await tester.pumpAndSettle();

      expect(find.text('업종 모드 선택'), findsOneWidget);

      await tester.tap(find.text('보험영업'));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(context);
      expect(container.read(industryModeProvider), 'insurance');
    });

    testWidgets('감지 스위치 토글 → provider + SharedPreferences 저장', (tester) async {
      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('detect_detect_screenshot')));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(context);
      expect(container.read(screenshotDetectEnabledProvider), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('detect_screenshot'), isTrue);
    });
  });

  group('PermissionScreen', () {
    testWidgets('렌더 스모크: 권한 항목 6개, 채널 실패 시 확인 불가', (tester) async {
      await tester.pumpWidget(wrap(const PermissionScreen()));
      await tester.pumpAndSettle();
      // 플랫폼 채널이 응답하지 않는 테스트 환경 — 가상 시간을 진행시켜
      // _kStatusTimeout(3초) 타임아웃을 발화시킨다. 6개 항목 순차 확인이므로
      // 6×3초 이상 진행한다.
      await tester.pump(const Duration(seconds: 20));
      await tester.pumpAndSettle();

      expect(find.text('마이크'), findsOneWidget);
      expect(find.text('알림'), findsOneWidget);
      expect(find.text('화면 오버레이'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('연락처'), findsOneWidget);
      expect(find.text('사진/미디어'), findsOneWidget);

      // permission.status가 테스트 환경에서 실패 → '확인 불가' 표시
      expect(find.text('확인 불가'), findsNWidgets(6));
      // 요청 버튼은 항목마다 1개씩
      expect(find.widgetWithText(OutlinedButton, '요청'), findsNWidgets(6));
    });
  });
}
