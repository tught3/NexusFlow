import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: '거래처',
      message: '우선 관리할 관계와 거래처를 모아보는 화면입니다.',
    );
  }
}
