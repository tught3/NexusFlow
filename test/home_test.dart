// 홈 화면 4존 위젯 테스트 — homeSummaryProvider override로 가짜 데이터 주입.
// Supabase 미초기화 상태에서 렌더되어야 한다 (화면은 직접 Supabase를 호출하지 않는다).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/providers/auth_provider.dart';
import 'package:nexusflow/providers/home_provider.dart';
import 'package:nexusflow/screens/home/home_screen.dart';

final fakeSummary = HomeSummary(
  dueActions: [
    {
      'id': 'act1',
      'account_id': 'a1',
      'title': '견적서 전달',
      'account_name': '서울제약',
      'due_date': '2026-10-05',
    },
  ],
  topAccounts: [
    {
      'id': 'a1',
      'name': '서울제약',
      'health_score': 88,
      'health_grade': 'A',
      'last_interaction_at': '2026-10-03T10:00:00Z',
    },
    {
      'id': 'a2',
      'name': '부산보험',
      'health_score': 61,
      'health_grade': 'C',
    },
  ],
  recentInsights: [
    {
      'id': 'i1',
      'account_id': 'a1',
      'insight_type': 'opportunity',
      'content': '신약접수 가능성이 높아요. 최근 대화에서 3회 언급됐습니다.',
      'status': 'new',
      'priority_score': 1.5,
      'created_at': '2026-10-04T09:00:00Z',
      'account_name': '서울제약',
    },
  ],
  lastInteractionText: null,
);

Widget wrap({required List<Override> overrides}) {
  return ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWith((ref) => 'test-user'),
      ...overrides,
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

void main() {
  testWidgets('가짜 데이터: 브리핑 문장/우선순위 카드/인사이트 존이 실데이터로 렌더된다',
      (tester) async {
    await tester.pumpWidget(wrap(
      overrides: [homeSummaryProvider.overrideWith((ref) => fakeSummary)],
    ));
    await tester.pump();

    // ZONE 1 — 마감 팔로업 개수 기반 요약 문장
    expect(find.textContaining('오늘 마감할 팔로업이 1개'), findsOneWidget);
    // ZONE 2 — 거래처명 렌더 (우선순위 카드 + 인사이트 카드 배지)
    expect(find.text('서울제약'), findsWidgets);
    expect(find.text('부산보험'), findsOneWidget);
    expect(find.textContaining('Health 88'), findsOneWidget);
    // ZONE 4 — 인사이트 내용 렌더
    expect(find.textContaining('신약접수 가능성'), findsOneWidget);
    // 목업 잔재 없음
    expect(find.text('박원장'), findsNothing);
    expect(find.text('원주세브란스'), findsNothing);
  });

  testWidgets('빈 데이터: 빈 상태 문구로 렌더된다', (tester) async {
    await tester.pumpWidget(wrap(
      overrides: [homeSummaryProvider.overrideWith((ref) => HomeSummary.empty)],
    ));
    await tester.pump();

    expect(find.text('새로운 소식이 없어요. 기록을 남겨보세요'), findsOneWidget);
    expect(find.text('아직 거래처가 없어요'), findsOneWidget);
    expect(find.text('새로운 인사이트가 없어요'), findsOneWidget);
    expect(find.text('PlanFlow 연동 준비 중이에요. 곧 일정이 표시됩니다.'),
        findsOneWidget);
  });

  testWidgets('로딩 중: 스켈레톤 표시, 목업/빈 상태 문구 없음', (tester) async {
    final completer = Completer<HomeSummary>();
    await tester.pumpWidget(wrap(
      overrides: [
        homeSummaryProvider.overrideWith((ref) => completer.future),
      ],
    ));
    await tester.pump();

    expect(find.byKey(const Key('home_briefing_skeleton')), findsOneWidget);
    expect(find.text('새로운 소식이 없어요. 기록을 남겨보세요'), findsNothing);
    expect(find.text('아직 거래처가 없어요'), findsNothing);
  });
}
