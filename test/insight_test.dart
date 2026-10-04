// 인사이트 화면군 위젯 테스트 — provider override로 가짜 데이터 주입.
// Supabase 미초기화 상태에서 렌더되어야 한다 (화면은 직접 Supabase를 호출하지 않는다).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/providers/account_provider.dart';
import 'package:nexusflow/providers/auth_provider.dart';
import 'package:nexusflow/providers/insight_provider.dart';
import 'package:nexusflow/screens/insight/insight_detail_screen.dart';
import 'package:nexusflow/screens/insight/insight_list_screen.dart';

final fakeInsights = <Map<String, dynamic>>[
  {
    'id': 'i1',
    'account_id': 'a1',
    'insight_type': 'today_action',
    'content': 'follow-up 기한이 지났어요: 견적서 전달',
    'status': 'new',
    'priority_score': 1.5,
    'created_at': '2026-10-04T09:00:00Z',
  },
  {
    'id': 'i2',
    'account_id': null,
    'insight_type': 'risk',
    'content': '부산보험 - 30일간 접촉이 없었어요.',
    'status': 'reviewed',
    'priority_score': 1.4,
    'created_at': '2026-10-03T09:00:00Z',
  },
];

final fakeAccounts = <Map<String, dynamic>>[
  {'id': 'a1', 'name': '서울제약'},
];

final fakeDetail = InsightDetail(
  insight: fakeInsights[0],
  accountName: '서울제약',
);

Widget wrap(
  Widget child, {
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'test-user'),
      ...overrides,
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('InsightListScreen이 인사이트 카드 2개를 타입 배지와 함께 렌더한다',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const InsightListScreen(),
        overrides: [
          insightsProvider.overrideWith((ref) => fakeInsights),
          accountsProvider.overrideWith((ref) => fakeAccounts),
        ],
      ),
    );
    await tester.pump();

    // 카드 2개 — content로 확인
    expect(find.text('follow-up 기한이 지났어요: 견적서 전달'), findsOneWidget);
    expect(find.text('부산보험 - 30일간 접촉이 없었어요.'), findsOneWidget);
    // 타입 배지 (필터 칩 + 카드 배지 = 2회)
    expect(find.text('오늘 할 일'), findsNWidgets(2));
    expect(find.text('위험'), findsNWidgets(2));
    // status 'new' → NEW 배지 1개
    expect(find.text('NEW'), findsOneWidget);
    // 관련 거래처명 매핑
    expect(find.text('서울제약'), findsOneWidget);
  });

  testWidgets('InsightListScreen이 필터 칩으로 인사이트를 걸러낸다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const InsightListScreen(),
        overrides: [
          insightsProvider.overrideWith((ref) => fakeInsights),
          accountsProvider.overrideWith((ref) => fakeAccounts),
        ],
      ),
    );
    await tester.pump();

    // '위험' 칩 탭 (칩 라벨과 카드 배지가 같은 텍스트라 ChoiceChip으로 한정)
    await tester.tap(find.widgetWithText(ChoiceChip, '위험'));
    await tester.pump();

    expect(find.text('부산보험 - 30일간 접촉이 없었어요.'), findsOneWidget);
    expect(find.text('follow-up 기한이 지났어요: 견적서 전달'), findsNothing);
  });

  testWidgets('InsightDetailScreen이 내용/거래처명/피드백 버튼을 표시한다',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const InsightDetailScreen(insightId: 'i1'),
        overrides: [
          insightDetailProvider('i1').overrideWith((ref) => fakeDetail),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('follow-up 기한이 지났어요: 견적서 전달'), findsOneWidget);
    expect(find.text('서울제약'), findsOneWidget);
    expect(find.text('관련 거래처'), findsOneWidget);
    expect(find.text('도움이 됐어요'), findsOneWidget);
    expect(find.text('아니요'), findsOneWidget);
    expect(find.text('오늘은 그만 보기'), findsOneWidget);
  });
}
