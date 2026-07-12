import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'NexusFlow',
      message: '관계 데이터를 안전하게 불러오기 위해 로그인이 필요한 화면입니다.',
    );
  }
}
