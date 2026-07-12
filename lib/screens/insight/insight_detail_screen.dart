import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class InsightDetailScreen extends StatelessWidget {
  const InsightDetailScreen({super.key, required this.insightId});

  final String insightId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '인사이트 상세',
      message: '인사이트 $insightId의 대상, 이유, 근거, 추천 액션을 확인하는 화면입니다.',
    );
  }
}
