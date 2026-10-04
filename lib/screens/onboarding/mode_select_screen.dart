import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../nexusflow_core/industry_modes/industry_mode_service.dart';
import '../../providers/settings_provider.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);

class ModeSelectScreen extends ConsumerStatefulWidget {
  const ModeSelectScreen({super.key});

  @override
  ConsumerState<ModeSelectScreen> createState() => _ModeSelectScreenState();
}

class _ModeSelectScreenState extends ConsumerState<ModeSelectScreen> {
  void _selectMode(String code) {
    ref.read(industryModeProvider.notifier).state = code;
    _saveMode(code);
  }

  Future<void> _saveMode(String code) async {
    final modeService = ref.read(industryModeServiceProvider);
    if (modeService == null) return;
    try {
      await modeService.saveUserMode(code);
    } catch (error) {
      debugPrint('업종 모드 저장 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = ref.watch(industryModeProvider);

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
                    '어떤 영업을 하고 계신가요?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '업종에 맞춰 용어와 추천이 달라져요. 나중에 설정에서 바꿀 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final entry
                      in IndustryModeService.modeInfos.entries) ...[
                    _buildModeCard(
                      info: entry.value,
                      selected: entry.key == selectedMode,
                      onTap: () => _selectMode(entry.key),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () => context.push('/onboarding/import'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '다음',
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

  Widget _buildModeCard({
    required IndustryModeInfo info,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              info.icon,
              style: const TextStyle(fontSize: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info.description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: _kTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 22,
                color: _kPrimary,
              ),
          ],
        ),
      ),
    );
  }
}
