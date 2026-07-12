import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/placeholder_screen.dart';

class ImportScreen extends StatelessWidget {
  const ImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '데이터 가져오기',
      message: 'PlanFlow 일정, 텍스트, 파일, OCR 결과를 관계 데이터로 정리하는 진입점입니다.',
      actionLabel: '홈으로 이동',
      onAction: () => context.go('/home'),
    );
  }
}
