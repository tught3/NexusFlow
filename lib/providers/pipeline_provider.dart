import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../nexusflow_core/confidence/nexusflow_pipeline.dart';
import 'auth_provider.dart';
import 'settings_provider.dart';

final pipelineProvider = Provider<NexusflowPipeline?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final industryMode = ref.watch(industryModeProvider);
  if (userId == null) return null;

  return NexusflowPipeline(
    supabase: Supabase.instance.client,
    userId: userId,
    industryMode: industryMode,
  );
});

final pipelineStateProvider =
    StateNotifierProvider<PipelineStateNotifier, AsyncValue<NexusflowPipelineResult?>>(
  (ref) => PipelineStateNotifier(ref),
);

class PipelineStateNotifier
    extends StateNotifier<AsyncValue<NexusflowPipelineResult?>> {
  PipelineStateNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<NexusflowPipelineResult?> process({
    required String rawText,
    required NexusflowInputSource source,
  }) async {
    state = const AsyncValue.loading();
    try {
      final pipeline = ref.read(pipelineProvider);
      if (pipeline == null) throw Exception('파이프라인 초기화 실패');

      final result = await pipeline.process(
        rawText: rawText,
        source: source,
      );
      state = AsyncValue.data(result);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  void reset() => state = const AsyncValue.data(null);
}
