import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/placeholder_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '시작하기',
      message: 'NexusFlow가 관계 데이터를 정리하고 추천하기 전에 기본 흐름을 설정합니다.',
      actionLabel: '동의 화면으로',
      onAction: () => context.push('/onboarding/consent'),
    );
  }
}
