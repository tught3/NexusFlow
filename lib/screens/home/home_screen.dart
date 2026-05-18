import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widgets/briefing_zone.dart';
import 'widgets/priority_card.dart';
import 'widgets/schedule_zone.dart';
import 'widgets/insight_zone.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // TODO: 전체 새로고침
          },
          child: CustomScrollView(
            slivers: [
              // 상단 앱바
              SliverAppBar(
                floating: true,
                backgroundColor: const Color(0xFFF8FAFC),
                elevation: 0,
                title: Row(
                  children: [
                    Image.asset('assets/logo.png', height: 28,
                      errorBuilder: (_, __, ___) => const Text(
                        'NexusFlow',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16213E),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () {},
                  ),
                ],
              ),

              // ZONE 1: 오늘 브리핑
              const SliverToBoxAdapter(child: BriefingZone()),

              // ZONE 2: 우선순위 카드 (가로 스와이프)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: PriorityCardZone(),
                ),
              ),

              // ZONE 3: 오늘 일정
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: ScheduleZone(),
                ),
              ),

              // ZONE 4: 최근 인사이트
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16, bottom: 100),
                  child: InsightZone(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
