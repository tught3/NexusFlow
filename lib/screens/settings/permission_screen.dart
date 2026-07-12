import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '권한 설정',
      message: '음성, 알림, OCR, 오버레이 권한 상태를 확인하고 필요한 시점에 요청하는 화면입니다.',
    );
  }
}
