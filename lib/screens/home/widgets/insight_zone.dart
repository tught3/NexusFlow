import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nexusflow/providers/home_provider.dart';

class InsightZone extends StatelessWidget {
  const InsightZone({super.key, required this.summary});

  final AsyncValue<HomeSummary> summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 인사이트',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16213E),
                ),
              ),
              TextButton(
                // Shell 하단탭의 인사이트로 전환
                onPressed: () => context.go('/insights'),
                child: const Text('전체보기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (summary.isLoading)
          const _SkeletonCard()
        else ..._buildCards(context),
      ],
    );
  }

  List<Widget> _buildCards(BuildContext context) {
    final insights = (summary.value?.recentInsights ?? const []).take(3).toList();
    if (insights.isEmpty) return const [_EmptyCard()];

    return [
      for (final insight in insights)
        _InsightCard(
          type: insight['insight_type']?.toString() ?? '',
          accountName: insight['account_name']?.toString() ?? '',
          content: insight['content']?.toString() ?? '',
          onTap: () => context.push('/insights/${insight['id']}'),
        ),
    ];
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.type,
    required this.accountName,
    required this.content,
    required this.onTap,
  });

  final String type;
  final String accountName;
  final String content;
  final VoidCallback onTap;

  Color get _typeColor {
    switch (type) {
      case 'opportunity':
        return const Color(0xFF16A34A);
      case 'risk':
        return const Color(0xFFDC2626);
      case 'today_action':
      case 'followup':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData get _typeIcon {
    switch (type) {
      case 'today_action':
        return Icons.task_alt;
      case 'opportunity':
        return Icons.trending_up;
      case 'risk':
        return Icons.warning_amber_rounded;
      case 'visit_timing':
        return Icons.event;
      case 'followup':
        return Icons.schedule;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _typeColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_typeIcon, color: _typeColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (accountName.isNotEmpty)
                    Text(
                      accountName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16213E),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  Text(
                    content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF334155),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: Color(0xFF64748B), size: 18),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      alignment: Alignment.center,
      child: const Text(
        '새로운 인사이트가 없어요',
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < 2; i++) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
