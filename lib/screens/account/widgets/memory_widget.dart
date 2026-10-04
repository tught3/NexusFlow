import 'package:flutter/material.dart';

/// 확정 기억(confirmed_memories) 목록 — 데이터 없으면 위젯 자체를 숨긴다.
class MemoryWidget extends StatelessWidget {
  const MemoryWidget({super.key, required this.memories});

  final List<Map<String, dynamic>> memories;

  // 스키마 컬럼명이 확정되지 않아 가능한 키를 순서대로 탐색한다.
  static String? _contentOf(Map<String, dynamic> memory) {
    for (final key in ['content', 'memory_content', 'summary', 'title']) {
      final value = memory[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final contents = memories
        .map(_contentOf)
        .whereType<String>()
        .toList(growable: false);
    if (contents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final content in contents)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.push_pin_outlined,
                  size: 14,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF16213E),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
