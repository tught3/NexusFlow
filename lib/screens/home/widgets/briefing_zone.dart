import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:nexusflow/providers/home_provider.dart';

class BriefingZone extends StatelessWidget {
  const BriefingZone({super.key, required this.summary});

  final AsyncValue<HomeSummary> summary;

  String _briefingText(HomeSummary data) {
    final due = data.dueActions.length;
    final insights = data.recentInsights.length;
    if (due > 0 && insights > 0) {
      return '오늘 마감할 팔로업이 $due개 · 새 인사이트 ${insights}개 있어요';
    }
    if (due > 0) return '오늘 마감할 팔로업이 $due개 있어요';
    if (insights > 0) return '확인할 인사이트가 $insights개 있어요';
    return '새로운 소식이 없어요. 기록을 남겨보세요';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayLabel = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';

    return GestureDetector(
      // 음성 브리핑 미구현 — 인사이트 탭으로 이동
      onTap: () => context.go('/insights'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dayLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: Colors.white54, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            if (summary.isLoading)
              const SizedBox(
                key: Key('home_briefing_skeleton'),
                width: 220,
                child: _SkeletonBar(),
              )
            else
              Text(
                _briefingText(summary.value ?? HomeSummary.empty),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              '인사이트 탭에서 자세히 보기',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
