// 기록 화면 - 음성/텍스트/파일 입력 + 파이프라인 연결
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../flow_core/stt/stt_service.dart';
import '../../nexusflow_core/confidence/nexusflow_pipeline.dart';
import '../../providers/pipeline_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/confidence_badge.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordedText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _isRecording = true;
      _recordedText = '';
    });
    // TODO: STT 서비스 연결
  }

  Future<void> _stopRecording() async {
    setState(() => _isRecording = false);
    if (_recordedText.isNotEmpty) {
      await _processInput(_recordedText, NexusflowInputSource.voice_memo);
    }
  }

  Future<void> _processInput(
    String text,
    NexusflowInputSource source,
  ) async {
    if (text.trim().isEmpty) return;
    setState(() => _isProcessing = true);

    final result = await ref
        .read(pipelineStateProvider.notifier)
        .process(rawText: text, source: source);

    setState(() => _isProcessing = false);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('처리 중 오류가 발생했어요.')),
      );
      return;
    }

    // Confidence Routing
    switch (result.routingLevel) {
      case ConfidenceLevel2.high:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ 자동으로 저장됐어요.')),
        );
        context.pop();
      case ConfidenceLevel2.mid:
        context.push('/confirm?extractionId=${result.extractionId}');
      case ConfidenceLevel2.low:
        context.push('/validation?extractionId=${result.extractionId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipelineState = ref.watch(pipelineStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        title: const Text(
          '기록하기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF16213E),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF2563EB),
          tabs: const [
            Tab(icon: Icon(Icons.mic), text: '음성'),
            Tab(icon: Icon(Icons.edit), text: '텍스트'),
            Tab(icon: Icon(Icons.attach_file), text: '파일'),
          ],
        ),
      ),
      body: pipelineState.isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI가 분석 중이에요...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _VoiceTab(
                  isRecording: _isRecording,
                  recordedText: _recordedText,
                  onStart: _startRecording,
                  onStop: _stopRecording,
                ),
                _TextTab(
                  controller: _textController,
                  onSubmit: () => _processInput(
                    _textController.text,
                    NexusflowInputSource.manual,
                  ),
                ),
                const _FileTab(),
              ],
            ),
    );
  }
}

// 음성 탭
class _VoiceTab extends StatelessWidget {
  const _VoiceTab({
    required this.isRecording,
    required this.recordedText,
    required this.onStart,
    required this.onStop,
  });

  final bool isRecording;
  final String recordedText;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: isRecording ? onStop : onStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isRecording ? 100 : 80,
              height: isRecording ? 100 : 80,
              decoration: BoxDecoration(
                color: isRecording
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (isRecording
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF2563EB))
                        .withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRecording ? '녹음 중... 탭하면 중지' : '탭하면 녹음 시작',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          if (recordedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                recordedText,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// 텍스트 탭
class _TextTab extends StatelessWidget {
  const _TextTab({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: '거래처 방문 내용, 통화 내용 등을 자유롭게 입력하세요.\n\n예) 박원장 방문. 신약접수 논의했고 다음주 화요일 follow-up 예정.',
                hintStyle: const TextStyle(
                  color: Color(0xFFCBD5E1),
                  fontSize: 14,
                  height: 1.6,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'AI 분석 시작',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 파일 탭
class _FileTab extends StatelessWidget {
  const _FileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.upload_file_outlined,
            size: 64,
            color: const Color(0xFF64748B).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'TXT, CSV, Excel 파일을 업로드하세요',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: file_picker 연결
            },
            icon: const Icon(Icons.attach_file),
            label: const Text('파일 선택'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ConfidenceLevel 별칭 (nexusflow_pipeline.dart의 enum과 충돌 방지)
typedef ConfidenceLevel2 = ConfidenceLevel;
