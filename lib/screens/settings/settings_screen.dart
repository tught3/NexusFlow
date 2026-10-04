import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../../flow_core/supabase_client/auth_service.dart';
import '../../nexusflow_core/industry_modes/industry_mode_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kChipBg = Color(0xFFF1F5F9);

class _DetectItem {
  const _DetectItem({
    required this.prefKey,
    required this.provider,
    required this.title,
    required this.subtitle,
  });

  final String prefKey;
  final StateProvider<bool> provider;
  final String title;
  final String subtitle;
}

final List<_DetectItem> _kDetectItems = [
  _DetectItem(
    prefKey: kDetectScreenshotKey,
    provider: screenshotDetectEnabledProvider,
    title: '스크린샷 감지',
    subtitle: '캡처한 이미지에서 일정·내용을 추출해요',
  ),
  _DetectItem(
    prefKey: kDetectSmsKey,
    provider: smsDetectEnabledProvider,
    title: 'SMS 감지',
    subtitle: '문자로 받은 일정·예약을 자동 기록해요',
  ),
  _DetectItem(
    prefKey: kDetectKakaoKey,
    provider: kakaoDetectEnabledProvider,
    title: '카톡 알림 감지',
    subtitle: '카카오톡 알림에서 약속을 잡아내요',
  ),
  _DetectItem(
    prefKey: kDetectCallKey,
    provider: callDetectEnabledProvider,
    title: '통화 녹음 감지',
    subtitle: '통화 후 요약과 할 일을 만들어요',
  ),
];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // 감지 플래그 복원 (SharedPreferences → StateProvider, 1회)
    ref.read(detectFlagsInitProvider);
  }

  Future<void> _selectMode(String code) async {
    ref.read(industryModeProvider.notifier).state = code;

    // 미로그인 또는 Supabase 미초기화 환경에서는 로컬 상태만 변경
    IndustryModeService? modeService;
    try {
      modeService = ref.read(industryModeServiceProvider);
    } catch (error) {
      debugPrint('업종 모드 서비스 접근 실패: $error');
    }
    if (modeService == null) return;

    try {
      await modeService.saveUserMode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업종 모드를 변경했어요')),
      );
    } catch (error) {
      debugPrint('업종 모드 저장 실패: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업종 모드 저장에 실패했어요')),
      );
    }
  }

  void _showModeSheet() {
    final currentMode = ref.read(industryModeProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '업종 모드 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final entry in IndustryModeService.modeInfos.entries)
                  _sheetModeCard(
                    info: entry.value,
                    selected: entry.key == currentMode,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _selectMode(entry.key);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleDetect(_DetectItem item, bool value) async {
    ref.read(item.provider.notifier).state = value;
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(item.prefKey, value);
  }

  Future<void> _signOut() async {
    // AuthService는 이벤트 핸들러 내에서만 생성 (테스트 크래시 방지)
    try {
      await AuthService().signOut();
    } catch (error) {
      debugPrint('로그아웃 실패: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃에 실패했어요')),
      );
    }
  }

  Future<void> _restartOnboarding() async {
    final prefs = await ref.read(sharedPrefsProvider.future);
    await prefs.setBool(kOnboardingCompletedKey, false);
    ref.invalidate(onboardingCompletedProvider);
    if (mounted) context.go('/onboarding');
  }

  /// authProvider는 Supabase.instance를 참조 — 미초기화(테스트 등) 환경에서 null로 폴백
  User? _watchAuthUser() {
    try {
      return ref.watch(authProvider).value;
    } catch (error) {
      debugPrint('인증 상태 확인 실패: $error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(industryModeProvider);
    final modeInfo = IndustryModeService.modeInfos[mode] ??
        IndustryModeService.modeInfos['general']!;
    final user = _watchAuthUser();
    final email = user?.email;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _sectionHeader('업종 모드'),
          _card(
            InkWell(
              key: const ValueKey('mode_section'),
              onTap: _showModeSheet,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(modeInfo.icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            modeInfo.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _kTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            modeInfo.description,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: _kTextSecondary),
                  ],
                ),
              ),
            ),
          ),
          _sectionHeader('자동 감지'),
          _card(
            Column(
              children: [
                for (var i = 0; i < _kDetectItems.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, thickness: 1, color: _kBorder),
                  _detectTile(_kDetectItems[i]),
                ],
              ],
            ),
          ),
          _sectionHeader('계정'),
          _card(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.account_circle,
                      size: 28, color: _kTextSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      email ?? '로그인되지 않았어요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: email != null ? _kTextPrimary : _kTextSecondary,
                      ),
                    ),
                  ),
                  if (email != null)
                    TextButton(
                      onPressed: _signOut,
                      child: const Text('로그아웃'),
                    )
                  else
                    TextButton(
                      onPressed: () => context.push('/auth/login'),
                      child: const Text('로그인'),
                    ),
                ],
              ),
            ),
          ),
          _card(
            Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.replay, size: 20, color: _kTextSecondary),
                  title: const Text(
                    '온보딩 다시 보기',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 20, color: _kTextSecondary),
                  onTap: _restartOnboarding,
                ),
                const Divider(height: 1, thickness: 1, color: _kBorder),
                ListTile(
                  leading: const Icon(Icons.verified_user,
                      size: 20, color: _kTextSecondary),
                  title: const Text(
                    '권한 설정',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      size: 20, color: _kTextSecondary),
                  onTap: () => context.push('/settings/permissions'),
                ),
              ],
            ),
          ),
          _sectionHeader('앱 정보'),
          _card(
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NexusFlow',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                      ),
                      const Text(
                        '0.1.0 — 1차 배포 전',
                        style: TextStyle(
                            fontSize: 12, color: _kTextSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '말했더니 알아서 정리됨',
                    style: TextStyle(fontSize: 12.5, color: _kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detectTile(_DetectItem item) {
    final enabled = ref.watch(item.provider);
    return SwitchListTile(
      key: ValueKey('detect_${item.prefKey}'),
      value: enabled,
      activeColor: _kPrimary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        item.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _kTextPrimary,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              item.subtitle,
              style: const TextStyle(fontSize: 12, color: _kTextSecondary),
            ),
            _nativePendingBadge(),
          ],
        ),
      ),
      onChanged: (value) => _toggleDetect(item, value),
    );
  }

  Widget _nativePendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _kChipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        '네이티브 감지 준비 중',
        style: TextStyle(fontSize: 10, color: _kTextSecondary),
      ),
    );
  }

  Widget _sheetModeCard({
    required IndustryModeInfo info,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _kChipBg : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(info.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  Text(
                    info.description,
                    style: const TextStyle(
                        fontSize: 12, color: _kTextSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 20, color: _kPrimary),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kTextSecondary,
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
