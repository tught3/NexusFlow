import 'package:flutter/material.dart';

class ScheduleZone extends StatelessWidget {
  const ScheduleZone({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '오늘 일정',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16213E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // PlanFlow 연동 전 — 일정 데이터 소스 없음
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.event_busy, color: Color(0xFF94A3B8), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'PlanFlow 연동 준비 중이에요. 곧 일정이 표시됩니다.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
