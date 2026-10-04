import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

const Color _kBackground = Color(0xFFF8FAFC);
const Color _kTextPrimary = Color(0xFF16213E);
const Color _kTextSecondary = Color(0xFF64748B);
const Color _kPrimary = Color(0xFF2563EB);
const Color _kBorder = Color(0xFFE2E8F0);
const Color _kChipBg = Color(0xFFF1F5F9);

enum _PermStatus { checking, granted, denied, permanentlyDenied, unknown }

/// 플랫폼 채널 응답 대기 상한 — 테스트 등 채널이 응답 없는 환경에서 '확인 불가'로 폴백
const Duration _kStatusTimeout = Duration(seconds: 3);

class _PermItem {
  const _PermItem({
    required this.key,
    required this.permission,
    required this.icon,
    required this.name,
    required this.description,
  });

  final String key;
  final Permission permission;
  final IconData icon;
  final String name;
  final String description;
}

const List<_PermItem> _kPermItems = [
  _PermItem(
    key: 'microphone',
    permission: Permission.microphone,
    icon: Icons.mic,
    name: '마이크',
    description: '음성 메모 녹음 및 전사 (RecordAudio)',
  ),
  _PermItem(
    key: 'notification',
    permission: Permission.notification,
    icon: Icons.notifications,
    name: '알림',
    description: '카톡 알림 감지와 리마인드 표시 (PostNotification)',
  ),
  _PermItem(
    key: 'system_alert_window',
    permission: Permission.systemAlertWindow,
    icon: Icons.layers,
    name: '화면 오버레이',
    description: '감지 결과를 다른 앱 위에 표시 (SYSTEM_ALERT_WINDOW)',
  ),
  _PermItem(
    key: 'sms',
    permission: Permission.sms,
    icon: Icons.sms,
    name: 'SMS',
    description: '문자로 받은 일정·예약 자동 감지 (READ_SMS)',
  ),
  _PermItem(
    key: 'contacts',
    permission: Permission.contacts,
    icon: Icons.contacts,
    name: '연락처',
    description: '발신자 이름 매칭과 참석자 추천 (READ_CONTACTS)',
  ),
  _PermItem(
    key: 'photos',
    permission: Permission.photos,
    icon: Icons.photo_library,
    name: '사진/미디어',
    description: '스크린샷 이미지 읽기 (감지용)',
  ),
];

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key});

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends ConsumerState<PermissionScreen> {
  final Map<Permission, _PermStatus> _statuses = {
    for (final item in _kPermItems) item.permission: _PermStatus.checking,
  };

  @override
  void initState() {
    super.initState();
    // permission.status는 플랫폼 채널이 필요 — 테스트 등 실패 시 '확인 불가'
    Future.microtask(_loadStatuses);
  }

  Future<void> _loadStatuses() async {
    for (final item in _kPermItems) {
      _PermStatus status;
      try {
        status = _mapStatus(
          await item.permission.status.timeout(_kStatusTimeout),
        );
      } catch (error) {
        debugPrint('권한 상태 확인 실패 (${item.key}): $error');
        status = _PermStatus.unknown;
      }
      if (!mounted) return;
      setState(() => _statuses[item.permission] = status);
    }
  }

  _PermStatus _mapStatus(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return _PermStatus.granted;
      case PermissionStatus.permanentlyDenied:
      case PermissionStatus.restricted:
        return _PermStatus.permanentlyDenied;
      case PermissionStatus.denied:
      default:
        return _PermStatus.denied;
    }
  }

  Future<void> _request(_PermItem item) async {
    _PermStatus status;
    try {
      status = _mapStatus(
        await item.permission.request().timeout(_kStatusTimeout),
      );
    } catch (error) {
      debugPrint('권한 요청 실패 (${item.key}): $error');
      status = _PermStatus.unknown;
    }
    if (!mounted) return;
    setState(() => _statuses[item.permission] = status);
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
    } catch (error) {
      debugPrint('앱 설정 열기 실패: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        title: const Text(
          '권한 설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'NexusFlow가 자동으로 정리하려면 아래 권한이 필요해요. 필요한 항목만 허용해도 돼요.',
              style: TextStyle(
                fontSize: 12.5,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
          ),
          for (final item in _kPermItems) _permCard(item),
        ],
      ),
    );
  }

  Widget _permCard(_PermItem item) {
    final status = _statuses[item.permission] ?? _PermStatus.checking;
    return Container(
      key: ValueKey('perm_${item.key}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _kChipBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 20, color: _kTextPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                      fontSize: 12, color: _kTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(item, status),
        ],
      ),
    );
  }

  Widget _statusChip(_PermStatus status) {
    final (label, color) = switch (status) {
      _PermStatus.checking => ('확인 중', _kTextSecondary),
      _PermStatus.granted => ('허용됨', const Color(0xFF16A34A)),
      _PermStatus.denied => ('거부됨', const Color(0xFFD97706)),
      _PermStatus.permanentlyDenied => ('영구 거부', const Color(0xFFDC2626)),
      _PermStatus.unknown => ('확인 불가', _kTextSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _actionButton(_PermItem item, _PermStatus status) {
    if (status == _PermStatus.permanentlyDenied) {
      return OutlinedButton(
        onPressed: _openAppSettings,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kPrimary,
          side: const BorderSide(color: _kPrimary),
          visualDensity: VisualDensity.compact,
        ),
        child: const Text('설정 열기', style: TextStyle(fontSize: 12.5)),
      );
    }
    final enabled = status == _PermStatus.denied ||
        status == _PermStatus.unknown ||
        status == _PermStatus.checking;
    return OutlinedButton(
      onPressed: enabled ? () => _request(item) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimary,
        side: const BorderSide(color: _kPrimary),
        visualDensity: VisualDensity.compact,
      ),
      child: const Text('요청', style: TextStyle(fontSize: 12.5)),
    );
  }
}
