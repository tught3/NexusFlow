// 인사이트 상세 화면 — 내용 전문, 관련 거래처, 피드백.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/insight_provider.dart';
import 'insight_list_screen.dart';

class InsightDetailScreen extends ConsumerStatefulWidget {
  const InsightDetailScreen({super.key, required this.insightId});

  final String insightId;

  @override
  ConsumerState<InsightDetailScreen> createState() =>
      _InsightDetailScreenState();
}

class _InsightDetailScreenState extends ConsumerState<InsightDetailScreen> {
  bool? _feedback; // null: 미응답, true: 도움됨, false: 도움 안 됨
  bool _feedbackSending = false;
  bool _suppressing = false;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendFeedback(bool helpful) async {
    if (_feedback != null || _feedbackSending) return;
    setState(() => _feedbackSending = true);
    try {
      await ref
          .read(insightRepositoryProvider)
          .sendFeedback(widget.insightId, helpful: helpful);
      if (!mounted) return;
      setState(() {
        _feedback = helpful;
        _feedbackSending = false;
      });
      ref.invalidate(insightsProvider);
      _showSnackBar(
        helpful ? '소중한 의견이에요, 감사해요' : '알겠어요, 더 나은 인사이트를 찾아볼게요',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedbackSending = false);
      _showSnackBar('피드백 전송에 실패했어요');
    }
  }

  Future<void> _suppressToday() async {
    if (_suppressing) return;
    setState(() => _suppressing = true);
    try {
      await ref.read(insightRepositoryProvider).suppressInsight(widget.insightId);
      ref.invalidate(insightsProvider);
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _suppressing = false);
      _showSnackBar('그만 보기 설정에 실패했어요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(insightDetailProvider(widget.insightId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '인사이트',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF16213E),
          ),
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Text(
              error is StateError
                  ? error.message
                  : '인사이트를 불러오지 못했어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: () =>
                    ref.invalidate(insightDetailProvider(widget.insightId)),
                child: const Text('다시 시도'),
              ),
            ),
          ],
        ),
        data: (detail) {
          final style = InsightTypeStyle.of(detail.insightType);
          final isNew = detail.status == 'new';
          final createdAt =
              DateTime.tryParse(detail.insight['created_at']?.toString() ?? '');
          final hasAccount =
              detail.accountId != null && detail.accountId!.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 인사이트 본문 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: style.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(style.icon,
                                    size: 13, color: style.color),
                                const SizedBox(width: 4),
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: style.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isNew) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: style.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: style.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        detail.content,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: Color(0xFF16213E),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${createdAt.year}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.day.toString().padLeft(2, '0')} '
                          '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} 생성',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 관련 거래처 카드
                if (hasAccount) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.push('/accounts/${detail.accountId}'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 20,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '관련 거래처',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detail.accountName ?? '거래처 정보 없음',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF16213E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // 피드백 카드
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '이 인사이트가 도움이 됐나요?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16213E),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  (_feedback != null || _feedbackSending)
                                      ? null
                                      : () => _sendFeedback(true),
                              icon: const Icon(Icons.thumb_up_outlined,
                                  size: 16),
                              label: const Text('도움이 됐어요'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _feedback == true
                                    ? const Color(0xFF2563EB)
                                    : const Color(0xFF16213E),
                                side: BorderSide(
                                  color: _feedback == true
                                      ? const Color(0xFF2563EB)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed:
                                  (_feedback != null || _feedbackSending)
                                      ? null
                                      : () => _sendFeedback(false),
                              icon: const Icon(Icons.thumb_down_outlined,
                                  size: 16),
                              label: const Text('아니요'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _feedback == false
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF16213E),
                                side: BorderSide(
                                  color: _feedback == false
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_feedbackSending)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _suppressing ? null : _suppressToday,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _suppressing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('오늘은 그만 보기'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
