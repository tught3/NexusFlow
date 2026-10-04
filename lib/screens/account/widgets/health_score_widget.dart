import 'package:flutter/material.dart';

/// 관계 Health Score 카드 — 큰 점수 + 등급 배지 + 하위 5개 진행바.
/// total이 null이면 계산 안내 문구 + [계산하기] 콜백 버튼.
class HealthScoreWidget extends StatelessWidget {
  const HealthScoreWidget({
    super.key,
    this.total,
    this.grade,
    this.contactFrequency,
    this.responseQuality,
    this.reliability,
    this.continuity,
    this.opportunity,
    this.onCalculate,
  });

  final int? total;
  final String? grade;
  final int? contactFrequency;
  final int? responseQuality;
  final int? reliability;
  final int? continuity;
  final int? opportunity;
  final VoidCallback? onCalculate;

  static Color _gradeColor(String? grade) {
    switch (grade) {
      case 'Strong':
        return const Color(0xFF16A34A);
      case 'Stable':
        return const Color(0xFF2563EB);
      case 'Warming':
        return const Color(0xFFF59E0B);
      case 'AtRisk':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFDC2626);
    }
  }

  static String _gradeLabel(String? grade) {
    switch (grade) {
      case 'Strong':
        return '🟢 Strong';
      case 'Stable':
        return '🔵 Stable';
      case 'Warming':
        return '🟡 Warming';
      case 'AtRisk':
        return '🟠 At Risk';
      default:
        return '🔴 Critical';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (total == null) {
      return _card(
        child: Column(
          children: [
            const Text(
              '아직 계산된 점수가 없어요',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            if (onCalculate != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onCalculate,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('점수 계산하기'),
              ),
            ],
          ],
        ),
      );
    }

    final color = _gradeColor(grade);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16213E),
                ),
              ),
              const Text(
                ' / 100',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _gradeLabel(grade),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _scoreBar('접촉빈도', contactFrequency, 25),
          _scoreBar('반응온도', responseQuality, 25),
          _scoreBar('이행률', reliability, 20),
          _scoreBar('지속성', continuity, 20),
          _scoreBar('기회신호', opportunity, 10),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _scoreBar(String label, int? score, int max) {
    final value = score == null ? 0.0 : (score / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16213E),
                ),
              ),
              const Spacer(),
              Text(
                '${score ?? 0}/$max',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }
}
