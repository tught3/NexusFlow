// Confidence Routing 순수 로직 단위테스트 — Supabase/네트워크 미사용.
// 파이프라인 인스턴스는 SupabaseClient가 필요해 생성할 수 없으므로
// static으로 노출된 메서드(detectPii/matchDictionary/applyDictionaryBonus/
// calculateOverallConfidence/route)를 직접 검증한다.
import 'package:flutter_test/flutter_test.dart';

import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart';

void main() {
  // 마스터플랜 Confidence 기준표 가중치 — 기대값은 계산식으로 산출(하드코딩 금지).
  const wAccount = 2.0;
  const wContact = 2.0;
  const wProduct = 1.5;
  const wSchedule = 1.5;
  const wActionItems = 1.0;
  const wSignals = 0.8;

  group('route — Confidence 라우팅 임계값', () {
    test('0.80 이상은 high (경계 포함)', () {
      expect(NexusflowPipeline.route(0.80), ConfidenceLevel.high);
      expect(NexusflowPipeline.route(1.0), ConfidenceLevel.high);
    });

    test('0.79는 high 미만이라 mid', () {
      expect(NexusflowPipeline.route(0.79), ConfidenceLevel.mid);
    });

    test('0.55 이상은 mid (경계 포함)', () {
      expect(NexusflowPipeline.route(0.55), ConfidenceLevel.mid);
    });

    test('0.54 미만은 low (하한 경계 0.0 포함)', () {
      expect(NexusflowPipeline.route(0.54), ConfidenceLevel.low);
      expect(NexusflowPipeline.route(0.0), ConfidenceLevel.low);
    });
  });

  group('calculateOverallConfidence — 가중 평균', () {
    test('4종 항목이 모두 0.9면 종합 0.9 (high)', () {
      final extracted = {
        'account': {'confidence': 0.9},
        'contact': {'confidence': 0.9},
        'product': {'confidence': 0.9},
        'schedule': {'confidence': 0.9},
      };
      final expected = (0.9 * wAccount +
              0.9 * wContact +
              0.9 * wProduct +
              0.9 * wSchedule) /
          (wAccount + wContact + wProduct + wSchedule);
      final result = NexusflowPipeline.calculateOverallConfidence(extracted);
      expect(result, closeTo(expected, 1e-9));
      expect(NexusflowPipeline.route(result), ConfidenceLevel.high);
    });

    test('account 0.9 + contact 0.3 → 가중 평균 0.6 (mid)', () {
      final extracted = {
        'account': {'confidence': 0.9},
        'contact': {'confidence': 0.3},
      };
      final expected =
          (0.9 * wAccount + 0.3 * wContact) / (wAccount + wContact);
      final result = NexusflowPipeline.calculateOverallConfidence(extracted);
      expect(result, closeTo(expected, 1e-9));
      expect(NexusflowPipeline.route(result), ConfidenceLevel.mid);
    });

    test('action_items는 항목 confidence 평균에 가중치 1.0 적용', () {
      final extracted = {
        'account': {'confidence': 1.0},
        'action_items': [
          {'content': '견적 발송', 'due_date': null, 'confidence': 0.8},
          {'content': '미팅 확정', 'due_date': null, 'confidence': 0.6},
        ],
      };
      final actionAvg = (0.8 + 0.6) / 2;
      final expected =
          (1.0 * wAccount + actionAvg * wActionItems) /
              (wAccount + wActionItems);
      expect(
        NexusflowPipeline.calculateOverallConfidence(extracted),
        closeTo(expected, 1e-9),
      );
    });

    test('signals는 항목 confidence 평균에 가중치 0.8 적용', () {
      final extracted = {
        'account': {'confidence': 1.0},
        'signals': [
          {'type': 'opportunity', 'content': '예산 확보', 'confidence': 0.5},
        ],
      };
      final expected = (1.0 * wAccount + 0.5 * wSignals) / (wAccount + wSignals);
      expect(
        NexusflowPipeline.calculateOverallConfidence(extracted),
        closeTo(expected, 1e-9),
      );
    });

    test('빈 extracted는 0.5 폴백', () {
      expect(NexusflowPipeline.calculateOverallConfidence(<String, dynamic>{}),
          0.5);
    });

    test('confidence 누락 항목은 totalWeight에서 제외', () {
      final extracted = {
        'account': {'name': 'A사'}, // confidence 없음 → 제외
        'contact': {'confidence': 0.4},
        'action_items': [
          {'content': 'confidence 없는 항목'}, // 제외
        ],
        'signals': [
          {'type': 'risk', 'content': 'confidence 없는 신호'}, // 제외
        ],
      };
      final expected = (0.4 * wContact) / wContact; // contact만 반영
      expect(
        NexusflowPipeline.calculateOverallConfidence(extracted),
        closeTo(expected, 1e-9),
      );
    });
  });

  group('detectPii — PII 감지', () {
    test('전화번호 감지', () {
      final flags = NexusflowPipeline.detectPii('김철수 010-1234-5678 연락 요망');
      expect(flags['phone'], ['010-1234-5678']);
    });

    test('이메일 감지', () {
      final flags = NexusflowPipeline.detectPii('메일은 abc@x.com 로 보내주세요');
      expect(flags['email'], ['abc@x.com']);
    });

    test('금액 감지', () {
      final flags = NexusflowPipeline.detectPii('총 3만 원 견적 드립니다');
      expect(flags['amount'], ['3만 원']);
    });

    test('혼합 텍스트는 세 종류 모두 감지', () {
      final flags = NexusflowPipeline.detectPii('010-1234-5678로 abc@x.com, 3만 원');
      expect(flags.containsKey('phone'), isTrue);
      expect(flags.containsKey('email'), isTrue);
      expect(flags.containsKey('amount'), isTrue);
    });

    test('PII 없으면 빈 맵', () {
      expect(NexusflowPipeline.detectPii('다음 주 미팅 확정 부탁드립니다'), isEmpty);
    });
  });

  group('matchDictionary — Dictionary 매칭 보너스', () {
    test('매칭된 term만 0.15 보너스, 비매칭은 제외', () {
      final dictionary = [
        {'term': 'VIP', 'meaning': '최우대 고객', 'dict_scope': 'industry'},
        {'term': '매칭안되는용어', 'meaning': 'x', 'dict_scope': 'general'},
      ];
      final bonuses =
          NexusflowPipeline.matchDictionary('VIP 고객 방문 예정', dictionary);
      expect(bonuses, {'VIP': 0.15});
    });

    test('매칭 없으면 빈 맵', () {
      final bonuses = NexusflowPipeline.matchDictionary('일반 문의 드립니다', [
        {'term': 'VIP', 'meaning': '최우대 고객', 'dict_scope': 'industry'},
      ]);
      expect(bonuses, isEmpty);
    });
  });

  group('applyDictionaryBonus — 보너스 적용', () {
    test('매칭 보너스만큼 confidence 상향', () {
      final extracted = {
        'account': {'name': 'A사', 'confidence': 0.7},
      };
      final boosted =
          NexusflowPipeline.applyDictionaryBonus(extracted, {'VIP': 0.15});
      expect(
        (boosted['account'] as Map)['confidence'],
        closeTo(0.7 + 0.15, 1e-9),
      );
    });

    test('1.0 상한 클램프', () {
      final extracted = {
        'account': {'name': 'A사', 'confidence': 0.95},
      };
      final boosted =
          NexusflowPipeline.applyDictionaryBonus(extracted, {'VIP': 0.15});
      expect((boosted['account'] as Map)['confidence'], 1.0);
    });

    test('보너스 없으면 원본 그대로', () {
      final extracted = {
        'account': {'name': 'A사', 'confidence': 0.7},
      };
      expect(
        NexusflowPipeline.applyDictionaryBonus(extracted, {}),
        equals(extracted),
      );
    });
  });
}
