import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/settings_provider.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);

class _ImportOption {
  const _ImportOption({
    required this.label,
    required this.description,
    required this.icon,
  });

  final String label;
  final String description;
  final IconData icon;
}

const List<_ImportOption> _options = [
  _ImportOption(
    label: '연락처',
    description: '휴대폰 주소록에서 거래처·담당자를 찾아요.',
    icon: Icons.contacts_outlined,
  ),
  _ImportOption(
    label: '기존 메모',
    description: '써둔 메모와 노트를 관계 구조로 정리해요.',
    icon: Icons.sticky_note_2_outlined,
  ),
];

class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kOnboardingCompletedKey, true);
    } catch (error) {
      debugPrint('온보딩 완료 저장 실패: $error');
    }
    // FutureProvider 캐시(false)를 갱신하지 않으면 redirect가 같은 실행 내에서
    // 계속 /onboarding으로 되보내 온보딩 루프에 빠진다.
    ref.invalidate(onboardingCompletedProvider);
    if (!context.mounted) return;
    // 완료 플래그 저장 후 이동 — 라우터 redirect가 상태에 맞는 화면으로 보낸다.
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '기존 데이터를 가져올 수 있어요',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '지금은 건너뛰어도 괜찮아요. 나중에 설정에서 언제든 가져올 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 표시는 하되 아직 준비 중 — 비활성
                  for (final option in _options) ...[
                    _buildOptionTile(option),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => _start(context, ref),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(_ImportOption option) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(option.icon, size: 20, color: _kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '준비 중',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _kTextSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
