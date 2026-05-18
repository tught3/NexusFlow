import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class InsightZone extends ConsumerWidget {
  const InsightZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                onPressed: () => context.push('/insights'),
                child: const Text('전체보기'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // TODO: 실제 데이터 연결
        _InsightCard(
          type: 'opportunity',
          accountName: '박원장',
          content: '신약접수 가능성이 높아졌어요. 최근 대화에서 3회 언급됐습니다.',
          onTap: () => context.push('/insights/insight_1'),
          onDismiss: () {},
        ),
        _InsightCard(
          type: 'risk',
          accountName: '김과장',
          content: '경쟁약 언급 후 21일간 follow-up이 없었어요.',
          onTap: () => context.push('/insights/insight_2'),
          onDismiss: () {},
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.type,
    required this.accountName,
    required this.content,
    required this.onTap,
    required this.onDismiss,
  });

  final String type;
  final String accountName;
  final String content;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  Color get _typeColor {
    switch (type) {
      case 'opportunity': return const Color(0xFF16A34A);
      case 'risk': return const Color(0xFFDC2626);
      case 'followup': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }

  String get _typeLabel {
    switch (type) {
      case 'opportunity': return '기회';
      case 'risk': return '리스크';
      case 'followup': return 'follow-up';
      default: return '정보';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('insight_$accountName'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFF64748B),
        child: const Icon(Icons.close, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: _typeColor, width: 3),
            ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: _typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          accountName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16213E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
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
      ),
    );
  }
}
