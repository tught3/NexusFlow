import 'package:flutter/material.dart';

/// 인터랙션 타임라인 — 좌측 세로 라인 + 점 스타일.
/// events: interaction_events 행 리스트 (event_type/summary/occurred_at).
class TimelineWidget extends StatelessWidget {
  const TimelineWidget({super.key, required this.events});

  final List<Map<String, dynamic>> events;

  static IconData _typeIcon(String? eventType) {
    switch (eventType) {
      case 'voice':
        return Icons.mic;
      case 'sms':
        return Icons.sms;
      case 'call':
        return Icons.call;
      case 'kakao':
        return Icons.chat;
      case 'note':
      default:
        return Icons.edit_note;
    }
  }

  static String _formatTime(dynamic occurredAt) {
    final parsed = DateTime.tryParse(occurredAt?.toString() ?? '');
    if (parsed == null) return '';
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            '기록이 아직 없어요',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++)
          _buildItem(events[i], isFirst: i == 0, isLast: i == events.length - 1),
      ],
    );
  }

  Widget _buildItem(
    Map<String, dynamic> event, {
    required bool isFirst,
    required bool isLast,
  }) {
    final eventType = event['event_type']?.toString();
    final summary = event['summary']?.toString();
    final time = _formatTime(event['occurred_at']);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (isFirst)
                  const SizedBox(height: 14)
                else
                  const Expanded(
                    child: VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
                if (isLast)
                  const SizedBox(height: 4)
                else
                  const Expanded(
                    child: VerticalDivider(
                      width: 2,
                      thickness: 2,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _typeIcon(eventType),
                        size: 14,
                        color: const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (summary == null || summary.isEmpty) ? '(요약 없음)' : summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF16213E),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
