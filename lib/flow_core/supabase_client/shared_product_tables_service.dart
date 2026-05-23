import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharedProductTablesService {
  SharedProductTablesService({
    SupabaseClient? client,
    this.schemaName = 'public',
    this.product = 'nexusflow',
    this.source = 'app',
  }) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String schemaName;
  final String product;
  final String source;

  static const Set<String> _bugReportTypes = <String>{
    'bug',
    'ux',
    'feature_request',
    'perf',
    'other',
  };

  static const Set<String> _sharedStatuses = <String>{'new', 'wip', 'done'};

  Future<void> submitBugReport({
    required String type,
    required String description,
    required Object deviceInfo,
    String status = 'new',
  }) async {
    _requireAllowedValue(type: type, allowed: _bugReportTypes, field: 'type');
    _requireAllowedValue(
      type: status,
      allowed: _sharedStatuses,
      field: 'status',
    );
    _requireNonEmpty(description, 'description');
    _requireNonEmpty(deviceInfo, 'device_info');

    await _client
        .schema(schemaName)
        .from('feedback_reports')
        .insert(<String, dynamic>{
          'product': product,
          'source': source,
          'type': type,
          'description': description.trim(),
          'device_info': deviceInfo,
          'status': status,
        });
  }

  Future<void> submitFeedbackMessage({
    required String name,
    required String email,
    required String subject,
    required String message,
    String status = 'new',
  }) async {
    _requireAllowedValue(
      type: status,
      allowed: _sharedStatuses,
      field: 'status',
    );
    _requireNonEmpty(name, 'name');
    _requireNonEmpty(email, 'email');
    _requireNonEmpty(subject, 'subject');
    _requireNonEmpty(message, 'message');

    await _client
        .schema(schemaName)
        .from('contact_messages')
        .insert(<String, dynamic>{
          'product': product,
          'source': source,
          'name': name.trim(),
          'email': email.trim(),
          'subject': subject.trim(),
          'message': message.trim(),
          'status': status,
        });
  }

  Future<void> submitEarlyBirdEmail({required String email}) async {
    _requireNonEmpty(email, 'email');

    await _client.schema(schemaName).from('product_early_birds').insert(
      <String, dynamic>{
        'product': product,
        'source': source,
        'email': email.trim(),
      },
    );
  }

  void _requireAllowedValue({
    required String type,
    required Set<String> allowed,
    required String field,
  }) {
    if (!allowed.contains(type)) {
      throw ArgumentError.value(
        type,
        field,
        'Allowed values: ${allowed.join(', ')}',
      );
    }
  }

  void _requireNonEmpty(Object? value, String field) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      throw ArgumentError.value(value, field, 'Must not be empty');
    }
  }
}

final sharedProductTablesServiceProvider = Provider<SharedProductTablesService>(
  (ref) {
    return SharedProductTablesService();
  },
);
