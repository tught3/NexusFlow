import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/placeholder_screen.dart';

class ModeSelectScreen extends StatelessWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '업종 모드',
      message: '제약영업과 보험영업을 우선 모드로 두고, 공통 관계 구조 위에 추천 기준을 얹습니다.',
      actionLabel: '데이터 가져오기',
      onAction: () => context.push('/onboarding/import'),
    );
  }
}
