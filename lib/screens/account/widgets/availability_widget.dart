import 'package:flutter/material.dart';

/// 담당자 가용 시간대 요약 칩 — 데이터 없으면 위젯 자체를 숨긴다.
class AvailabilityWidget extends StatelessWidget {
  const AvailabilityWidget({super.key, required this.slots});

  final List<Map<String, dynamic>> slots;

  // 스키마 컬럼명이 확정되지 않아 가능한 키를 순서대로 탐색한다.
  static String? _slotLabel(Map<String, dynamic> slot) {
    for (final key in ['slot_label', 'time_slot', 'label', 'name']) {
      final value = slot[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    final day = slot['day_of_week']?.toString();
    final start = slot['start_time']?.toString();
    final end = slot['end_time']?.toString();
    final parts = [
      if (day != null && day.isNotEmpty) day,
      if (start != null && start.isNotEmpty)
        '$start${end != null && end.isNotEmpty ? '~$end' : ''}',
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final labels =
        slots.map(_slotLabel).whereType<String>().toList(growable: false);
    if (labels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🕐 자주 응답하는 시간대',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF16213E),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final label in labels)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
