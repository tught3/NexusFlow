class NexusflowFab {
// NexusFlow 글로벌 FAB - 모든 화면에서 음성입력/AI검색 접근
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class NexusflowFab extends ConsumerStatefulWidget {
  const NexusflowFab({super.key});

  @override
  ConsumerState<NexusflowFab> createState() => _NexusflowFabState();
}

class _NexusflowFabState extends ConsumerState<NexusflowFab>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _onVoiceInput() {
    _toggle();
    context.push('/record?mode=voice');
  }

  void _onAiSearch() {
    _toggle();
    context.push('/record?mode=ai');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 음성 입력 버튼
        ScaleTransition(
          scale: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'fab_voice',
              backgroundColor: const Color(0xFF2563EB),
              onPressed: _onVoiceInput,
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
          ),
        ),
        // AI 검색 버튼
        ScaleTransition(
          scale: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FloatingActionButton.small(
              heroTag: 'fab_ai',
              backgroundColor: const Color(0xFF06B6D4),
              onPressed: _onAiSearch,
              child: const Icon(Icons.auto_awesome,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
        // 메인 FAB
        FloatingActionButton(
          heroTag: 'fab_main',
          backgroundColor: const Color(0xFF16213E),
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isExpanded ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
}
