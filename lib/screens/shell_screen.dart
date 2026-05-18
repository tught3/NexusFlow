import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../widgets/nexusflow_fab.dart';

class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    final tabs = [
      (path: '/home', icon: Icons.home_outlined, activeIcon: Icons.home, label: '홈'),
      (path: '/accounts', icon: Icons.business_outlined, activeIcon: Icons.business, label: '거래처'),
      (path: '/record', icon: Icons.add_circle_outline, activeIcon: Icons.add_circle, label: '기록'),
      (path: '/insights', icon: Icons.lightbulb_outline, activeIcon: Icons.lightbulb, label: '인사이트'),
      (path: '/settings', icon: Icons.settings_outlined, activeIcon: Icons.settings, label: '설정'),
    ];

    int currentIndex = tabs.indexWhere((t) => location.startsWith(t.path));
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      floatingActionButton: const NexusflowFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => context.go(tabs[index].path),
        destinations: tabs.map((t) => NavigationDestination(
          icon: Icon(t.icon),
          selectedIcon: Icon(t.activeIcon),
          label: t.label,
        )).toList(),
      ),
    );
  }
}
