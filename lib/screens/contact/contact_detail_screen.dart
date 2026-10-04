import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/account_provider.dart';
import '../../widgets/industry_tag.dart';
import '../account/widgets/availability_widget.dart';
import '../account/widgets/timeline_widget.dart';

class ContactDetailScreen extends ConsumerWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(contactDetailProvider(contactId));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: detailAsync.maybeWhen(
          data: (detail) => Text(
            detail.contact['name']?.toString() ?? '담당자',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16213E),
            ),
          ),
          orElse: () => const Text(
            '담당자 상세',
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
        data: (detail) => _buildBody(context, ref, detail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.toString().contains('로그인')
                    ? '로그인이 필요합니다'
                    : '담당자 정보를 불러오지 못했어요',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(contactDetailProvider(contactId)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    ContactDetail detail,
  ) {
    final contact = detail.contact;
    final name = contact['name']?.toString() ?? '이름 없음';
    final role = contact['role']?.toString();
    final account = detail.account;
    final accountId = account?['id']?.toString();

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(refreshAccountDataProvider.notifier).state++;
        return ref.refresh(contactDetailProvider(contactId).future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // 프로필 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : '?',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF16213E),
                  ),
                ),
                if (role != null && role.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
                if (account != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: accountId != null && accountId.isNotEmpty
                        ? () => context.push('/accounts/$accountId')
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.business_outlined,
                            size: 15,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            account['name']?.toString() ?? '거래처',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IndustryTag(
                            mode: account['industry_mode']?.toString(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 가용 시간대 (데이터 없으면 카드 전체 숨김)
          if (detail.availabilitySlots.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: AvailabilityWidget(slots: detail.availabilitySlots),
            ),
            const SizedBox(height: 12),
          ],
          // 타임라인
          Container(
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
                const Text(
                  '최근 활동',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF16213E),
                  ),
                ),
                const SizedBox(height: 10),
                TimelineWidget(events: detail.interactionEvents),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
