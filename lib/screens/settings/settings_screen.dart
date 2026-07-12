import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '설정',
      message: '권한, 업종 모드, 데이터 연결 상태를 관리하는 화면입니다.',
      actionLabel: '권한 설정 보기',
      onAction: () => context.push('/settings/permissions'),
    );
  }
}
