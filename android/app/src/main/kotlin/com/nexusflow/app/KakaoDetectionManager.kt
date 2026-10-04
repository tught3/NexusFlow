package com.nexusflow.app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 카카오톡 알림 감지 매니저.
 * - 채널: nexusflow/kakao (method), nexusflow/kakao_events (event)
 * - 실제 알림 수신은 NexusflowNotificationListener(NotificationListenerService)가 담당하고,
 *   서비스와 Activity 생명주기가 분리되므로 매칭 상태/싱크는 companion 싱글톤으로 공유한다.
 */
class KakaoDetectionManager(private val context: Context) : EventChannel.StreamHandler {

    companion object {
        const val KAKAO_PACKAGE = "com.kakao.talk"

        // NotificationListenerService가 접근하는 공유 상태
        @Volatile
        private var sink: EventChannel.EventSink? = null

        @Volatile
        private var knownContactNames: List<String> = emptyList()

        @Volatile
        private var keywords: List<String> = emptyList()

        private val mainHandler = Handler(Looper.getMainLooper())

        /** NexusflowNotificationListener에서 호출 — 매칭된 알림만 sink로 전달 */
        fun handleNotification(title: String?, text: String?) {
            val contacts = knownContactNames
            val kws = keywords
            if (contacts.isEmpty() && kws.isEmpty()) return

            // 매칭 로직: 단순 contains (제목 또는 본문)
            val haystack = "${title ?: ""} ${text ?: ""}"
            val matchedContact = contacts.firstOrNull { haystack.contains(it, ignoreCase = true) }
            val matchedKeywords = kws.filter { haystack.contains(it, ignoreCase = true) }
            if (matchedContact == null && matchedKeywords.isEmpty()) return

            val event = mapOf<String, Any?>(
                "sender" to (title ?: ""),
                "message" to (text ?: ""),
                // ID 매핑은 네이티브에 없음 — Dart 측에서 후처리
                "matchedContactId" to null,
                "matchedKeywords" to matchedKeywords,
                "receivedAt" to NativeUtils.isoTimestamp(),
            )
            mainHandler.post {
                val target = sink ?: return@post
                try {
                    target.success(event)
                } catch (_: Exception) {
                    // sink 오류 시 이벤트 폐기
                }
            }
        }
    }

    // ---------------------------------------------------------------- method

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasNotificationPermission" -> result.success(hasListenerPermission())
            "requestNotificationPermission" -> {
                // 알림 접근 권한 설정 화면으로 이동
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                } catch (_: Exception) {
                    // 설정 화면 실행 실패 시 무시 (Dart가 void로 처리)
                }
                result.success(null)
            }
            "startKakaoDetection" -> {
                knownContactNames =
                    call.argument<List<String>>("knownContactNames") ?: emptyList()
                keywords = call.argument<List<String>>("keywords") ?: emptyList()
                if (!hasListenerPermission()) {
                    result.error(
                        "PERMISSION_DENIED",
                        "알림 접근 권한(Notification Listener)이 없습니다.",
                        null,
                    )
                    return
                }
                result.success(null)
            }
            "stopKakaoDetection" -> {
                knownContactNames = emptyList()
                keywords = emptyList()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------------- event

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    fun stopAll() {
        sink = null
        knownContactNames = emptyList()
        keywords = emptyList()
    }

    // ---------------------------------------------------------------- 내부

    private fun hasListenerPermission(): Boolean {
        return try {
            val listeners = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            listeners.contains(context.packageName)
        } catch (_: Exception) {
            false
        }
    }
}
