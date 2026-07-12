import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ContactDetailScreen extends StatelessWidget {
  const ContactDetailScreen({super.key, required this.contactId});

  final String contactId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderScreen(
      title: '담당자 상세',
      message: '담당자 $contactId의 관계 히스토리와 다음 추천 액션을 확인하는 화면입니다.',
    );
  }
}
