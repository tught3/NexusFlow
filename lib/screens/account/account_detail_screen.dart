import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nexusflow_core/relationship/health_score_service.dart';
import '../../providers/account_provider.dart';
import '../../widgets/industry_tag.dart';
import 'widgets/health_score_widget.dart';
import 'widgets/memory_widget.dart';
import 'widgets/timeline_widget.dart';

class AccountDetailScreen extends ConsumerStatefulWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  ConsumerState<AccountDetailScreen> createState() =>
      _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  bool _calculating = false;

  // 방어적 파싱: num/String/null 모두 허용
  int? _asInt(dynamic value) => int.tryParse(value?.toString() ?? '');

  Future<void> _calculateHealth() async {
    if (_calculating) return;
    setState(() => _calculating = true);
    try {
      final service = ref.read(healthScoreServiceProvider);
      if (service != null) {
        await service.calculate(widget.accountId);
        ref.read(refreshAccountDataProvider.notifier).state++;
        ref.invalidate(accountDetailProvider(widget.accountId));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('점수 계산에 실패했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _calculating = false);
    }
  }

  Future<void> _toggleActionItem(Map<String, dynamic> item, bool done) async {
    try {
      await ref.read(accountRepositoryProvider).setActionItemStatus(
            item['id']?.toString() ?? '',
            status: done ? 'done' : 'pending',
          );
      ref.read(refreshAccountDataProvider.notifier).state++;
      ref.invalidate(accountDetailProvider(widget.accountId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상태를 변경하지 못했어요')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(accountDetailProvider(widget.accountId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: detailAsync.maybeWhen(
          data: (detail) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.account['name']?.toString() ?? '거래처',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF16213E),
                ),
              ),
              const SizedBox(height: 2),
              IndustryTag(
                mode: detail.account['industry_mode']?.toString(),
              ),
            ],
          ),
          orElse: () => const Text(
            '거래처 상세',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16213E),
            ),
          ),
        ),
      ),
      body: detailAsync.when(
        skipLoadingOnRefresh: true,
        data: (detail) => _buildBody(context, detail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.toString().contains('로그인')
                    ? '로그인이 필요합니다'
                    : '거래처 정보를 불러오지 못했어요',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(accountDetailProvider(widget.accountId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AccountDetail detail) {
    final account = detail.account;
    final actionItems = [...detail.actionItems]..sort((a, b) {
        final aDone = a['status']?.toString() == 'done';
        final bDone = b['status']?.toString() == 'done';
        if (aDone != bDone) return aDone ? 1 : -1;
        return 0;
      });

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(refreshAccountDataProvider.notifier).state++;
        return ref.refresh(accountDetailProvider(widget.accountId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (_calculating)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          HealthScoreWidget(
            total: _asInt(account['health_score']),
            grade: account['health_grade']?.toString(),
            contactFrequency: _asInt(account['health_contact_score']),
            responseQuality: _asInt(account['health_response_score']),
            reliability: _asInt(account['health_reliability_score']),
            continuity: _asInt(account['health_continuity_score']),
            opportunity: _asInt(account['health_opportunity_score']),
            onCalculate: _calculateHealth,
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '담당자',
            child: detail.contacts.isEmpty
                ? const _EmptyText('등록된 담당자가 없어요')
                : Column(
                    children: [
                      for (final contact in detail.contacts)
                        _ContactTile(contact: contact),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '최근 활동',
            child: TimelineWidget(events: detail.interactionEvents),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '액션 아이템',
            child: actionItems.isEmpty
                ? const _EmptyText('예정된 액션이 없어요')
                : Column(
                    children: [
                      for (final item in actionItems)
                        _ActionItemTile(
                          item: item,
                          onToggle: _toggleActionItem,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            title: '활성 신호',
            child: detail.activeSignals.isEmpty
                ? const _EmptyText('활성 신호가 없어요')
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final signal in detail.activeSignals)
                        _SignalChip(signal: signal),
                    ],
                  ),
          ),
          if (detail.memories.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionCard(
              title: '기억 노트',
              child: MemoryWidget(memories: detail.memories),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF16213E),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final Map<String, dynamic> contact;

  @override
  Widget build(BuildContext context) {
    final id = contact['id']?.toString() ?? '';
    final name = contact['name']?.toString() ?? '이름 없음';
    final role = contact['role']?.toString();

    return InkWell(
      onTap: () => context.push('/contacts/$id'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Text(
                name.isNotEmpty ? name.substring(0, 1) : '?',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                role == null || role.isEmpty ? name : '$name · $role',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF16213E),
                ),
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
    );
  }
}

class _ActionItemTile extends StatelessWidget {
  const _ActionItemTile({required this.item, required this.onToggle});

  final Map<String, dynamic> item;
  final void Function(Map<String, dynamic> item, bool done) onToggle;

  @override
  Widget build(BuildContext context) {
    final done = item['status']?.toString() == 'done';
    final content = item['content']?.toString() ?? '액션';
    final dueDate = DateTime.tryParse(item['due_date']?.toString() ?? '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: done,
              onChanged: (value) => onToggle(item, value ?? false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              content,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: done ? const Color(0xFF64748B) : const Color(0xFF16213E),
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (dueDate != null)
            Text(
              '${dueDate.month.toString().padLeft(2, '0')}/${dueDate.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({required this.signal});

  final Map<String, dynamic> signal;

  @override
  Widget build(BuildContext context) {
    final type = signal['signal_type']?.toString();
    final content = signal['signal_content']?.toString() ?? '';
    final isOpportunity = type == 'opportunity';
    final isRisk = type == 'risk';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpportunity
            ? const Color(0xFFDCFCE7)
            : isRisk
                ? const Color(0xFFFEE2E2)
                : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpportunity
                ? Icons.trending_up
                : isRisk
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
            size: 13,
            color: isOpportunity
                ? const Color(0xFF16A34A)
                : isRisk
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              content.isEmpty ? (type ?? '신호') : content,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOpportunity
                    ? const Color(0xFF16A34A)
                    : isRisk
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
