// 확인 모달 - MID Confidence 항목 간단 확인
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/confidence_badge.dart';
import '../../providers/auth_provider.dart';

class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.extractionId});
  final String extractionId;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  Map<String, dynamic>? _extraction;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExtraction();
  }

  Future<void> _loadExtraction() async {
    final result = await Supabase.instance.client
        .schema('nexusflow')
        .from('ai_extractions')
        .select('extracted_data, confidence_score')
        .eq('id', widget.extractionId)
        .single();
    setState(() {
      _extraction = result;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await Supabase.instance.client
        .schema('nexusflow')
        .from('ai_extractions')
        .update({'status': 'confirmed'})
        .eq('id', widget.extractionId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ 저장됐어요.')),
      );
      context.pop();
    }
  }

  Future<void> _dismiss() async {
    await Supabase.instance.client
        .schema('nexusflow')
        .from('ai_extractions')
        .update({'status': 'rejected'})
        .eq('id', widget.extractionId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '이렇게 저장할까요?',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16213E),
                          ),
                        ),
                        if (_extraction != null)
                          ConfidenceBadge(
                            confidence: (_extraction!['confidence_score']
                                    as num)
                                .toDouble(),
                            size: ConfidenceBadgeSize.small,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_extraction != null)
                      _ExtractionPreview(
                        data: Map<String, dynamic>.from(
                          _extraction!['extracted_data'] is String
                              ? {}
                              : _extraction!['extracted_data'] as Map,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _dismiss,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('닫기'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    '저장',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ExtractionPreview extends StatelessWidget {
  const _ExtractionPreview({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final items = <_PreviewItem>[];

    final account = data['account'];
    if (account is Map) {
      items.add(_PreviewItem(
        icon: Icons.business,
        label: '거래처',
        value: account['name']?.toString() ?? '',
        confidence: (account['confidence'] as num?)?.toDouble() ?? 0,
      ));
    }

    final contact = data['contact'];
    if (contact is Map) {
      items.add(_PreviewItem(
        icon: Icons.person,
        label: '담당자',
        value: contact['name']?.toString() ?? '',
        confidence: (contact['confidence'] as num?)?.toDouble() ?? 0,
      ));
    }

    final schedule = data['schedule'];
    if (schedule is Map) {
      items.add(_PreviewItem(
        icon: Icons.calendar_today,
        label: '일정',
        value: schedule['date']?.toString() ?? '',
        confidence: (schedule['confidence'] as num?)?.toDouble() ?? 0,
      ));
    }

    final summary = data['summary'];
    if (summary is String && summary.isNotEmpty) {
      items.add(_PreviewItem(
        icon: Icons.summarize,
        label: '요약',
        value: summary,
        confidence: 1.0,
        showBadge: false,
      ));
    }

    return Column(
      children: items.map((item) => _PreviewRow(item: item)).toList(),
    );
  }
}

class _PreviewItem {
  const _PreviewItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.confidence,
    this.showBadge = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final double confidence;
  final bool showBadge;
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.item});
  final _PreviewItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 16, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF16213E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (item.showBadge)
            ConfidenceBadge(
              confidence: item.confidence,
              showLabel: false,
              size: ConfidenceBadgeSize.small,
            ),
        ],
      ),
    );
  }
}
