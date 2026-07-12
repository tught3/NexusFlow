// Confidence 배지 위젯 - AI 추출 신뢰도 표시
import 'package:flutter/material.dart';
import 'package:nexusflow/nexusflow_core/confidence/nexusflow_pipeline.dart' show ConfidenceLevel;

class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge({
    super.key,
    required this.confidence,
    this.showLabel = true,
    this.size = ConfidenceBadgeSize.normal,
  });

  final double confidence;
  final bool showLabel;
  final ConfidenceBadgeSize size;

  ConfidenceLevel get level {
    if (confidence >= 0.80) return ConfidenceLevel.high;
    if (confidence >= 0.55) return ConfidenceLevel.mid;
    return ConfidenceLevel.low;
  }

  Color get _color {
    switch (level) {
      case ConfidenceLevel.high: return const Color(0xFF16A34A);
      case ConfidenceLevel.mid: return const Color(0xFFF59E0B);
      case ConfidenceLevel.low: return const Color(0xFFDC2626);
    }
  }

  String get _label {
    switch (level) {
      case ConfidenceLevel.high: return '자동저장';
      case ConfidenceLevel.mid: return '확인필요';
      case ConfidenceLevel.low: return '검수필요';
    }
  }

  String get _icon {
    switch (level) {
      case ConfidenceLevel.high: return '✓';
      case ConfidenceLevel.mid: return '?';
      case ConfidenceLevel.low: return '!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = size == ConfidenceBadgeSize.small ? 10.0 : 12.0;
    final padding = size == ConfidenceBadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _icon,
            style: TextStyle(
              fontSize: fontSize,
              color: _color,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 3),
            Text(
              _label,
              style: TextStyle(
                fontSize: fontSize,
                color: _color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(width: 3),
          Text(
            '${(confidence * 100).toInt()}%',
            style: TextStyle(
              fontSize: fontSize,
              color: _color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

enum ConfidenceBadgeSize { small, normal }
