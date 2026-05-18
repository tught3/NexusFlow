import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PriorityCardZone extends ConsumerWidget {
  const PriorityCardZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '오늘 우선 관리할 관계',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF16213E),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5, // TODO: 실제 데이터 연결
            itemBuilder: (context, index) {
              return _PriorityCard(
                name: '박원장',
                accountName: '원주세브란스',
                urgencyColor: index == 0
                    ? const Color(0xFFDC2626)
                    : index == 1
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF16A34A),
                healthScore: 72 - (index * 8),
                reason: 'follow-up ${31 + index}일',
                accountId: 'account_$index',
                onTap: (id) => context.push('/accounts/$id'),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.name,
    required this.accountName,
    required this.urgencyColor,
    required this.healthScore,
    required this.reason,
    required this.accountId,
    required this.onTap,
  });

  final String name;
  final String accountName;
  final Color urgencyColor;
  final int healthScore;
  final String reason;
  final String accountId;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(accountId),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: urgencyColor.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: urgencyColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF16213E),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              accountName,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              reason,
              style: TextStyle(
                fontSize: 11,
                color: urgencyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Health $healthScore',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
