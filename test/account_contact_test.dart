// 거래처/담당자 화면군 위젯 테스트 — provider override로 가짜 데이터 주입.
// Supabase 미초기화 상태에서 렌더되어야 한다 (화면은 직접 Supabase를 호출하지 않는다).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/providers/account_provider.dart';
import 'package:nexusflow/providers/auth_provider.dart';
import 'package:nexusflow/screens/account/account_detail_screen.dart';
import 'package:nexusflow/screens/account/account_list_screen.dart';
import 'package:nexusflow/screens/account/widgets/health_score_widget.dart';
import 'package:nexusflow/screens/contact/contact_detail_screen.dart';

final fakeAccounts = <Map<String, dynamic>>[
  {
    'id': 'a1',
    'name': '서울제약',
    'industry_mode': 'pharma',
    'health_score': 85,
    'health_grade': 'Strong',
    'health_updated_at': '2026-10-01T09:30:00Z',
  },
  {
    'id': 'a2',
    'name': '부산보험',
    'industry_mode': 'insurance',
    'health_score': 42,
    'health_grade': 'Warming',
    'health_updated_at': null,
  },
];

final fakeAccountDetail = AccountDetail(
  account: {
    'id': 'a1',
    'name': '서울제약',
    'industry_mode': 'pharma',
    'health_score': 85,
    'health_grade': 'Strong',
    'health_contact_score': 20,
    'health_response_score': 18,
    'health_reliability_score': 17,
    'health_continuity_score': 12,
    'health_opportunity_score': 5,
    'health_updated_at': '2026-10-01T09:30:00Z',
  },
  contacts: [
    {'id': 'c1', 'name': '김약사', 'role': '약국장'},
    {'id': 'c2', 'name': '박과장', 'role': '구매팀'},
  ],
  interactionEvents: [
    {
      'id': 'e1',
      'event_type': 'call',
      'summary': '신규 제품 미팅 요청',
      'occurred_at': '2026-10-01T09:30:00Z',
    },
    {
      'id': 'e2',
      'event_type': 'kakao',
      'summary': '견적 관련 문의 회신',
      'occurred_at': '2026-09-28T14:10:00Z',
    },
  ],
  actionItems: [
    {'id': 'i1', 'content': '견적서 전달', 'status': 'pending', 'due_date': null},
    {'id': 'i2', 'content': '샘플 택배 발송', 'status': 'done', 'due_date': null},
  ],
  activeSignals: [
    {'id': 's1', 'signal_type': 'opportunity', 'signal_content': '신제품 관심'},
  ],
  memories: [
    {'id': 'm1', 'content': '커피를 좋아함'},
  ],
);

final fakeContactDetail = ContactDetail(
  contact: {'id': 'c1', 'name': '김약사', 'role': '약국장', 'account_id': 'a1'},
  account: {'id': 'a1', 'name': '서울제약', 'industry_mode': 'pharma'},
  interactionEvents: [
    {
      'id': 'e1',
      'event_type': 'call',
      'summary': '신규 제품 미팅 요청',
      'occurred_at': '2026-10-01T09:30:00Z',
    },
  ],
  availabilitySlots: [
    {'id': 'v1', 'slot_label': '평일 오전 10시'},
  ],
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
  testWidgets('AccountListScreen이 거래처 카드 2개를 렌더한다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountListScreen(),
        overrides: [
          accountsProvider.overrideWith((ref) => fakeAccounts),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('서울제약'), findsOneWidget);
    expect(find.text('부산보험'), findsOneWidget);
    // IndustryTag 라벨
    expect(find.textContaining('제약영업'), findsOneWidget);
    expect(find.textContaining('보험영업'), findsOneWidget);
  });

  testWidgets('AccountListScreen이 검색어로 거래처를 필터링한다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AccountListScreen(),
        overrides: [
          accountsProvider.overrideWith((ref) => fakeAccounts),
        ],
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), '부산');
    await tester.pump();

    expect(find.text('부산보험'), findsOneWidget);
    expect(find.text('서울제약'), findsNothing);
  });

  testWidgets('AccountDetailScreen이 거래처명/담당자/타임라인을 표시한다',
      (tester) async {
    // 세로로 긴 뷰포트 — 하단 섹션까지 한 번에 렌더
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        const AccountDetailScreen(accountId: 'a1'),
        overrides: [
          accountDetailProvider('a1')
              .overrideWith((ref) => fakeAccountDetail),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('서울제약'), findsOneWidget);
    expect(find.text('김약사 · 약국장'), findsOneWidget);
    expect(find.text('박과장 · 구매팀'), findsOneWidget);
    expect(find.text('신규 제품 미팅 요청'), findsOneWidget);
    expect(find.text('견적 관련 문의 회신'), findsOneWidget);
    expect(find.text('견적서 전달'), findsOneWidget);
    expect(find.textContaining('Strong'), findsWidgets);
  });

  testWidgets('ContactDetailScreen이 담당자명/소속 거래처를 표시한다',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const ContactDetailScreen(contactId: 'c1'),
        overrides: [
          contactDetailProvider('c1')
              .overrideWith((ref) => fakeContactDetail),
        ],
      ),
    );
    await tester.pump();

    // 앱바 타이틀 + 프로필 카드에 2회 표시
    expect(find.text('김약사'), findsNWidgets(2));
    expect(find.text('약국장'), findsOneWidget);
    expect(find.text('서울제약'), findsOneWidget);
    expect(find.text('평일 오전 10시'), findsOneWidget);
    expect(find.textContaining('자주 응답하는 시간대'), findsOneWidget);
  });

  testWidgets('HealthScoreWidget: 점수 85는 Strong 배지를 표시한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HealthScoreWidget(
            total: 85,
            grade: 'Strong',
            contactFrequency: 20,
            responseQuality: 18,
            reliability: 17,
            continuity: 12,
            opportunity: 5,
          ),
        ),
      ),
    );

    expect(find.text('85'), findsOneWidget);
    expect(find.textContaining('Strong'), findsOneWidget);
    expect(find.text('접촉빈도'), findsOneWidget);
    expect(find.text('기회신호'), findsOneWidget);
    expect(find.text('아직 계산된 점수가 없어요'), findsNothing);
  });

  testWidgets('HealthScoreWidget: null이면 계산 안내문을 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HealthScoreWidget()),
      ),
    );

    expect(find.text('아직 계산된 점수가 없어요'), findsOneWidget);
    expect(find.text('85'), findsNothing);
    // 콜백이 없으면 계산 버튼도 없다
    expect(find.text('점수 계산하기'), findsNothing);
  });
}
