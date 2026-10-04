import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/account_provider.dart';
import '../../widgets/industry_tag.dart';

class AccountListScreen extends ConsumerStatefulWidget {
  const AccountListScreen({super.key});

  @override
  ConsumerState<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends ConsumerState<AccountListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final search = ref.watch(accountsSearchProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '거래처',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF16213E),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(accountsSearchProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: '거래처 이름 검색',
                hintStyle: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Color(0xFF64748B),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(refreshAccountDataProvider.notifier).state++;
                await ref.refresh(accountsProvider.future);
              },
              child: accountsAsync.when(
                skipLoadingOnRefresh: true,
                data: (accounts) =>
                    _buildList(context, accounts, search: search),
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    const Text(
                      '거래처 목록을 불러오지 못했어요',
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
                        onPressed: () => ref.refresh(accountsProvider),
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

  Widget _buildList(
    BuildContext context,
    List<Map<String, dynamic>> accounts, {
    required String search,
  }) {
    final query = search.trim();
    final filtered = query.isEmpty
        ? accounts
        : accounts
            .where((account) => (account['name']?.toString() ?? '')
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList(growable: false);

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Text(
            '아직 거래처가 없어요.\n기록 탭에서 첫 기록을 남겨보세요',
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) =>
          _AccountCard(account: filtered[index]),
    );
  }
}

/// 방어적 숫자 파싱 — num/String/기타 어느 타입이 와도 크래시 없음
num? _asNum(dynamic value) => value is num ? value : null;

/// 목록 카드용 점수 배지 — 점수 숫자 + 등급색 점
class HealthScoreBadge extends StatelessWidget {
  const HealthScoreBadge({super.key, this.score, this.grade});

  final num? score;
  final String? grade;

  static Color _dotColor(String? grade) {
    switch (grade) {
      case 'Strong':
        return const Color(0xFF16A34A);
      case 'Stable':
        return const Color(0xFF2563EB);
      case 'Warming':
        return const Color(0xFFF59E0B);
      case 'AtRisk':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFDC2626);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (score == null) {
      return const Text(
        '-',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _dotColor(grade),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${score!.toInt()}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF16213E),
          ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final Map<String, dynamic> account;

  @override
  Widget build(BuildContext context) {
    final id = account['id']?.toString() ?? '';
    final name = account['name']?.toString() ?? '이름 없음';
    final updatedAt = DateTime.tryParse(
        account['health_updated_at']?.toString() ?? '');
    final activityLabel = updatedAt == null
        ? '최근 활동 기록 없음'
        : '최근 활동 ${updatedAt.month.toString().padLeft(2, '0')}/${updatedAt.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/accounts/$id'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16213E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IndustryTag(mode: account['industry_mode']?.toString()),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activityLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HealthScoreBadge(
              score: _asNum(account['health_score']),
              grade: account['health_grade']?.toString(),
            ),
            const SizedBox(width: 4),
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
