// 인사이트 목록 화면 — AI가 관계 데이터에서 발견한 신호를 모아 보여준다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nexusflow_core/insights/insight_engine.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/insight_provider.dart';

/// 인사이트 유형별 표시 정보
class InsightTypeStyle {
  const InsightTypeStyle({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  static InsightTypeStyle of(String? type) {
    switch (type) {
      case 'today_action':
        return const InsightTypeStyle(
          color: Color(0xFF2563EB),
          icon: Icons.task_alt,
          label: '오늘 할 일',
        );
      case 'opportunity':
        return const InsightTypeStyle(
          color: Color(0xFF16A34A),
          icon: Icons.trending_up,
          label: '기회',
        );
      case 'risk':
        return const InsightTypeStyle(
          color: Color(0xFFF59E0B),
          icon: Icons.warning_amber_rounded,
          label: '위험',
        );
      case 'visit_timing':
        return const InsightTypeStyle(
          color: Color(0xFF7C3AED),
          icon: Icons.schedule,
          label: '방문 타이밍',
        );
      default:
        return const InsightTypeStyle(
          color: Color(0xFF64748B),
          icon: Icons.lightbulb_outline,
          label: '인사이트',
        );
    }
  }
}

class _FilterOption {
  const _FilterOption(this.value, this.label);

  final String value;
  final String label;
}

const _filterOptions = [
  _FilterOption('all', '전체'),
  _FilterOption('today_action', '오늘 할 일'),
  _FilterOption('opportunity', '기회'),
  _FilterOption('risk', '위험'),
  _FilterOption('visit_timing', '방문 타이밍'),
];

class InsightListScreen extends ConsumerStatefulWidget {
  const InsightListScreen({super.key});

  @override
  ConsumerState<InsightListScreen> createState() => _InsightListScreenState();
}

class _InsightListScreenState extends ConsumerState<InsightListScreen> {
  bool _generating = false;
  final Set<String> _dismissedIds = {};

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 인사이트 엔진 재실행 → 목록 갱신
  Future<void> _generateInsights() async {
    final engine = ref.read(insightEngineProvider);
    if (engine == null) {
      _showSnackBar('로그인이 필요해요');
      return;
    }
    setState(() => _generating = true);
    try {
      await engine.generateAll();
    } catch (_) {
      // 생성 실패해도 저장된 목록은 다시 불러온다
    }
    if (!mounted) return;
    setState(() => _generating = false);
    ref.invalidate(insightsProvider);
  }

  /// 스와이프 dismiss → 7일간 그만 보기
  Future<void> _suppressOnServer(String insightId) async {
    try {
      await ref.read(insightRepositoryProvider).suppressInsight(insightId);
      ref.invalidate(insightsProvider);
      _showSnackBar('오늘은 이 인사이트를 숨겼어요');
    } catch (_) {
      _showSnackBar('그만 보기 설정에 실패했어요');
    }
  }

  void _onDismissed(String insightId) {
    setState(() => _dismissedIds.add(insightId));
    _suppressOnServer(insightId);
  }

  @override
  Widget build(BuildContext context) {
    final insightsAsync = ref.watch(insightsProvider);
    final filter = ref.watch(insightFilterProvider);
    final accountNames = ref.watch(accountsProvider).value ?? const [];

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
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: _generateInsights,
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: '새로 생성',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(filter),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(insightsProvider.future),
              child: insightsAsync.when(
                skipLoadingOnRefresh: true,
                data: (insights) => _buildList(
                  insights,
                  filter: filter,
                  accountNames: {
                    for (final row in accountNames)
                      row['id']?.toString() ?? '': row['name']?.toString() ?? '',
                  },
                ),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    const Text(
                      '인사이트를 불러오지 못했어요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton(
                        onPressed: () => ref.invalidate(insightsProvider),
                        child: const Text('다시 시도'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(String filter) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final option in _filterOptions)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: filter == option.value,
                  onSelected: (_) =>
                      ref.read(insightFilterProvider.notifier).state =
                          option.value,
                  selectedColor: const Color(0xFF2563EB),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: filter == option.value
                        ? Colors.white
                        : const Color(0xFF64748B),
                  ),
                  showCheckmark: false,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(
                    color: filter == option.value
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    List<Map<String, dynamic>> insights, {
    required String filter,
    required Map<String, String> accountNames,
  }) {
    final filtered = insights.where((insight) {
      if (_dismissedIds.contains(insight['id']?.toString())) return false;
      if (filter == 'all') return true;
      return insight['insight_type']?.toString() == filter;
    }).toList(growable: false);

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Text(
            '아직 인사이트가 없어요.\n기록이 쌓이면 AI가 관계 신호를 찾아줘요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final insight = filtered[index];
        final id = insight['id']?.toString() ?? '';
        return Dismissible(
          key: ValueKey('insight-$id'),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _onDismissed(id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.visibility_off,
                size: 22, color: Color(0xFFDC2626)),
          ),
          child: _InsightCard(
            insight: insight,
            accountName:
                accountNames[insight['account_id']?.toString() ?? ''],
          ),
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, this.accountName});

  final Map<String, dynamic> insight;
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final style = InsightTypeStyle.of(insight['insight_type']?.toString());
    final isNew = insight['status']?.toString() == 'new';
    final createdAt =
        DateTime.tryParse(insight['created_at']?.toString() ?? '');

    return GestureDetector(
      onTap: () => context.push('/insights/${insight['id']?.toString() ?? ''}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
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
                Icon(style.icon, size: 16, color: style.color),
                const SizedBox(width: 6),
                Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: style.color,
                  ),
                ),
                if (accountName != null && accountName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      accountName!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (isNew)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
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
            ),
            const SizedBox(height: 8),
            Text(
              insight['content']?.toString() ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: Color(0xFF16213E),
              ),
            ),
            if (createdAt != null) ...[
              const SizedBox(height: 6),
              Text(
                '${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')} '
                '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
