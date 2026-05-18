import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BriefingZone extends ConsumerWidget {
  const BriefingZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final dayLabel = '${now.month}월 ${now.day}일 ${weekdays[now.weekday - 1]}요일';

    return GestureDetector(
      onTap: () {
        // TODO: 음성 브리핑 시작
      },
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
                const Icon(Icons.volume_up_outlined,
                    color: Colors.white54, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            // TODO: 실제 데이터 연결
            const Text(
              '오늘 방문 3건 · follow-up 2건 지연',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '탭하면 음성 브리핑을 시작합니다',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
