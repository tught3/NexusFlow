import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/settings_provider.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);

/// SharedPreferences 키: 승인한 수집 채널 id 목록
const String kOnboardingConsentsKey = 'onboarding_consents';

class _ChannelInfo {
  const _ChannelInfo({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final IconData icon;
}

const List<_ChannelInfo> _channels = [
  _ChannelInfo(
    id: 'voice_memo',
    label: '음성 메모',
    description: '직접 녹음한 상담을 자동으로 정리해요.',
    icon: Icons.mic_none,
  ),
  _ChannelInfo(
    id: 'screenshot',
    label: '스크린샷',
    description: '명함·주소록 캡처를 읽어 담당자를 찾아요.',
    icon: Icons.photo_camera_outlined,
  ),
  _ChannelInfo(
    id: 'sms',
    label: 'SMS',
    description: '주고받은 문자에서 약속과 일정을 놓치지 않아요.',
    icon: Icons.sms_outlined,
  ),
  _ChannelInfo(
    id: 'kakao',
    label: '카카오톡 알림',
    description: '카톡 알림에서 다가오는 미팅을 챙겨요.',
    icon: Icons.forum_outlined,
  ),
  _ChannelInfo(
    id: 'call',
    label: '통화 녹음',
    description: '통화 후 기록을 정리할지 물어봐요.',
    icon: Icons.phone_in_talk_outlined,
  ),
];

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  late final Map<String, bool> _enabled = {
    // 음성 메모는 앱 안에서 직접 녹음하는 핵심 기능이라 기본 켜짐,
    // 자동 감지 채널(스크린샷/SMS/카톡/통화)은 기본 꺼짐 — 전부 선택 동의.
    for (final channel in _channels) channel.id: channel.id == 'voice_memo',
  };

  Future<void> _next() async {
    final enabledIds = <String>[
      for (final entry in _enabled.entries)
        if (entry.value) entry.key,
    ];

    // 감지 플래그 반영
    ref.read(screenshotDetectEnabledProvider.notifier).state =
        enabledIds.contains('screenshot');
    ref.read(smsDetectEnabledProvider.notifier).state =
        enabledIds.contains('sms');
    ref.read(callDetectEnabledProvider.notifier).state =
        enabledIds.contains('call');
    ref.read(kakaoDetectEnabledProvider.notifier).state =
        enabledIds.contains('kakao');

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(kOnboardingConsentsKey, enabledIds);
    } catch (error) {
      debugPrint('온보딩 동의 저장 실패: $error');
    }

    if (mounted) context.push('/onboarding/mode');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '어떤 흐름을 흡수할까요?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '동의한 채널만 들어와요. 필수 동의는 없고, 나중에 설정에서 언제든 바꿀 수 있어요.',
                    style: TextStyle(
                      fontSize: 13,
                      color: _kTextSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final channel in _channels) ...[
                    _buildChannelTile(channel),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _next,
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

  Widget _buildChannelTile(_ChannelInfo channel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            child: Icon(channel.icon, size: 20, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  channel.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  channel.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled[channel.id]!,
            onChanged: (value) =>
                setState(() => _enabled[channel.id] = value),
          ),
        ],
      ),
    );
  }
}
