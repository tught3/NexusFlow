import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class AccountDetailScreen extends StatelessWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '거래처 상세',
      message: '거래처 $accountId의 Health Score, 타임라인, 추천 액션을 확인하는 화면입니다.',
    );
  }
}
