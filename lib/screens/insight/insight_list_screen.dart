import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class InsightListScreen extends StatelessWidget {
  const InsightListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '인사이트',
      message: '관계 데이터에서 발견한 근거 기반 추천을 모아보는 화면입니다.',
    );
  }
}
