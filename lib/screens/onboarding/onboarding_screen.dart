import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

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
                  const SizedBox(height: 24),
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'NexusFlow',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '말했더니 알아서 정리됨',
                    style: TextStyle(fontSize: 14, color: _kTextSecondary),
                  ),
                  const SizedBox(height: 36),
                  const _FeatureRow(
                    icon: Icons.mic_none,
                    title: '자동 흡수',
                    description: '음성·사진·메시지를 기록하면 알아서 거둬가요.',
                  ),
                  const SizedBox(height: 14),
                  const _FeatureRow(
                    icon: Icons.auto_awesome,
                    title: 'AI 정리',
                    description: '흩어진 기록이 거래처·담당자 구조로 정리돼요.',
                  ),
                  const SizedBox(height: 14),
                  const _FeatureRow(
                    icon: Icons.question_answer_outlined,
                    title: '물어보는 구조',
                    description: '지난주 약속이 뭐였는지 물어보면 바로 답해요.',
                  ),
                  const SizedBox(height: 36),
                  FilledButton(
                    onPressed: () => context.push('/onboarding/consent'),
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
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
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
            child: Icon(icon, size: 20, color: _kPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
