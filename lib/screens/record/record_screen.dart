// 기록 화면 - 음성/텍스트/파일 입력 + 파이프라인 연결
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  bool _isRecording = false;
  bool _isProcessing = false;
  String _recordedText = '';
  String _partialText = '';
  bool _userRequestedStop = false;
  late final SttService _stt = SttService();
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _recordedText = '';
      _partialText = '';
      _userRequestedStop = false;
    });
    _pulseController.repeat(reverse: true);

    final result = await _stt.listen(
      onPartialResult: (text) {
        if (!mounted) return;
        setState(() => _partialText = text);
      },
    );

    if (!mounted) return;
    _pulseController.stop();
    setState(() {
      _isRecording = false;
      _partialText = '';
    });

    if (result.isSuccess) {
      final text = result.text!;
      _recordedText = text;
      // PlanFlow UX 관례: 성공 시 버튼 재탭 없이 파이프라인으로 바로 이어감.
      await _processInput(text, NexusflowInputSource.voice_memo);
      return;
    }

    final failure = result.failure;
    if (failure == null) return;
    // 사용자가 직접 중단했는데 입력이 없으면 조용히 종료.
    if (failure == SttListenFailure.silence && _userRequestedStop) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sttFailureMessage(failure, result.message ?? '')),
      ),
    );
  }

  Future<void> _stopRecording() async {
    _userRequestedStop = true;
    setState(() => _isRecording = false);
    // 진행 중 listen() Future를 완료시켜 _startRecording의 후속 흐름이 정리되게 한다.
    // processInput은 listen 완료 쪽에서만 실행되므로 여기서 중복 실행하지 않는다.
    await _stt.stopActiveListen();
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
                  partialText: _partialText,
                  pulseScale: _pulseScale,
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
                _FileTab(
                  onFileText: (text) => _processInput(
                    text,
                    NexusflowInputSource.file_upload,
                  ),
                ),
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
    required this.partialText,
    required this.pulseScale,
    required this.onStart,
    required this.onStop,
  });

  final bool isRecording;
  final String recordedText;
  final String partialText;
  final Animation<double> pulseScale;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: isRecording
                ? pulseScale
                : const AlwaysStoppedAnimation<double>(1.0),
            child: GestureDetector(
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
        ),
          const SizedBox(height: 24),
          Text(
            isRecording ? '녹음 중... 탭하면 중지' : '탭하면 녹음 시작',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          if (isRecording) ...[
            const SizedBox(height: 12),
            const Text(
              '🎤 듣고 있어요...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
            if (partialText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  partialText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
          ],
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

// 파일 탭 — file_picker로 TXT/MD/CSV를 받아 파이프라인에 file_upload로 넘긴다
class _FileTab extends StatefulWidget {
  const _FileTab({required this.onFileText});

  final Future<void> Function(String text) onFileText;

  @override
  State<_FileTab> createState() => _FileTabState();
}

class _FileTabState extends State<_FileTab> {
  static const int _maxBytes = 10 * 1024; // 10KB 초과 시 앞부분만 사용
  bool _isReading = false;

  // FilePicker 접근은 이 이벤트 핸들러 내부에서만 (테스트 크래시 방지)
  Future<void> _pickAndProcess() async {
    if (_isReading) return;
    setState(() => _isReading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md', 'csv'],
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return; // 사용자 취소

      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        _showReadError();
        return;
      }

      final text = await _readFileText(File(path));
      if (!mounted) return;
      if (text.trim().isEmpty) {
        _showReadError();
        return;
      }

      await widget.onFileText(text);
    } catch (_) {
      if (mounted) _showReadError();
    } finally {
      if (mounted) setState(() => _isReading = false);
    }
  }

  /// 10KB 이하면 전체, 초과면 앞 10KB만 읽음 (UTF-8 멀티바이트 잘림 허용).
  Future<String> _readFileText(File file) async {
    final length = await file.length();
    if (length <= _maxBytes) return file.readAsString();
    final raf = await file.open();
    try {
      final bytes = await raf.read(_maxBytes);
      return utf8.decode(bytes, allowMalformed: true);
    } finally {
      await raf.close();
    }
  }

  void _showReadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('파일을 읽지 못했어요')),
    );
  }

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
            'TXT, MD, CSV 파일을 업로드하세요',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isReading ? null : _pickAndProcess,
            icon: _isReading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.attach_file),
            label: Text(_isReading ? '읽는 중...' : '파일 선택'),
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

/// STT 실패 유형별 사용자 안내 메시지 (유닛 테스트 가능하도록 최상위 함수).
/// silence는 서비스가 제공한 message(fallback)를 그대로 사용.
String sttFailureMessage(SttListenFailure failure, String fallback) {
  switch (failure) {
    case SttListenFailure.permissionDenied:
      return '마이크 권한이 필요해요';
    case SttListenFailure.silence:
      return fallback.isNotEmpty ? fallback : '입력이 인식되지 않았어요. 다시 말씀해 주세요.';
    case SttListenFailure.unavailable:
      return '음성 인식을 사용할 수 없는 환경이에요';
    case SttListenFailure.unsupportedLocale:
      return '이 기기에서는 한국어 음성 인식을 지원하지 않아요';
  }
}
