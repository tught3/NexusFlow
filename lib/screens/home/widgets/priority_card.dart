import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nexusflow/providers/home_provider.dart';

class PriorityCardZone extends StatelessWidget {
  const PriorityCardZone({super.key, required this.summary});

  final AsyncValue<HomeSummary> summary;

  Color _gradeColor(String? grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF16A34A);
      case 'B':
        return const Color(0xFFF59E0B);
      case 'C':
      case 'D':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _lastInteractionLabel(Map<String, dynamic> account) {
    final raw = account['last_interaction_at'];
    final at = raw == null ? null : DateTime.tryParse(raw.toString());
    if (at == null) return '기록 없음';
    final days = DateTime.now().difference(at).inDays;
    if (days <= 0) return '오늘 기록';
    return '최근 기록 $days일 전';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '오늘 우선 관리할 관계',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16213E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (summary.isLoading)
          const _SkeletonCard()
        else ..._buildCards(context),
      ],
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final accounts = summary.value?.topAccounts ?? const [];
    if (accounts.isEmpty) return const [_EmptyCard()];

    return [
      SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            final grade = account['health_grade']?.toString();
            return _PriorityCard(
              name: account['name']?.toString() ?? '',
              gradeLabel:
                  grade == null || grade.isEmpty ? '등급 없음' : '$grade등급',
              urgencyColor: _gradeColor(grade),
              healthScore:
                  num.tryParse(account['health_score']?.toString() ?? '')
                          ?.round() ??
                      0,
              reason: _lastInteractionLabel(account),
              accountId: account['id']?.toString() ?? '',
              onTap: (id) => context.push('/accounts/$id'),
            );
          },
        ),
      ),
    ];
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.name,
    required this.gradeLabel,
    required this.urgencyColor,
    required this.healthScore,
    required this.reason,
    required this.accountId,
    required this.onTap,
  });

  final String name;
  final String gradeLabel;
  final Color urgencyColor;
  final int healthScore;
  final String reason;
  final String accountId;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(accountId),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: urgencyColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF16213E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              gradeLabel,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              reason,
              style: TextStyle(
                fontSize: 11,
                color: urgencyColor,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Health $healthScore',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: const Text(
        '아직 거래처가 없어요',
        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 140,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(80, 12),
          const SizedBox(height: 10),
          _bar(120, 10),
          const Spacer(),
          _bar(60, 10),
        ],
      ),
    );
  }

  Widget _bar(double width, double height) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
