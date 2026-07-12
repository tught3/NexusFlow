import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/placeholder_screen.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '데이터 동의',
      message: '음성, OCR, 알림 등 민감한 흐름 데이터는 저장 전 확인을 우선합니다.',
      actionLabel: '모드 선택',
      onAction: () => context.push('/onboarding/mode'),
    );
  }
}
