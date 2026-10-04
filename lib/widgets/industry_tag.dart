import 'package:flutter/material.dart';

import '../nexusflow_core/industry_modes/industry_mode_service.dart';

/// 업종 모드 칩 — mode 코드를 라벨+아이콘으로 표시
class IndustryTag extends StatelessWidget {
  const IndustryTag({super.key, this.mode});

  final String? mode;

  @override
  Widget build(BuildContext context) {
    final info = IndustryModeService.modeInfos[mode ?? ''] ??
        IndustryModeService.modeInfos['general']!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '${info.icon} ${info.label}',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}
