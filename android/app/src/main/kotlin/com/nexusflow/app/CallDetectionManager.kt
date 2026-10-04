package com.nexusflow.app

import android.Manifest
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 통화 종료 감지 매니저.
 * - 채널: nexusflow/call (method), nexusflow/call_events (event)
 * - TelephonyManager.listen(PhoneStateListener, LISTEN_CALL_STATE) 사용.
 *   Android 10+에서 CALL_STATE 감지는 READ_PHONE_STATE로 충분 (매니페스트에 이미 있음).
 * - 녹음 파일은 수집하지 않음 (recordingFilePath = null).
 */
class CallDetectionManager(private val context: Context) : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private var knownPhoneNumbers: List<String> = emptyList()
    private var telephonyManager: TelephonyManager? = null
    private var listenerAttached = false
    private val mainHandler = Handler(Looper.getMainLooper())

    // 통화 상태 추적
    private var callStartMillis = 0L
    private var lastPhoneNumber = ""

    @Suppress("DEPRECATION")
    private val phoneStateListener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            try {
                when (state) {
                    TelephonyManager.CALL_STATE_RINGING -> {
                        if (!phoneNumber.isNullOrBlank()) lastPhoneNumber = phoneNumber
                    }
                    TelephonyManager.CALL_STATE_OFFHOOK -> {
                        if (!phoneNumber.isNullOrBlank()) lastPhoneNumber = phoneNumber
                        // IDLE 전이 전 OFFHOOK이면 통화 중으로 간주
                        if (callStartMillis == 0L) {
                            callStartMillis = System.currentTimeMillis()
                        }
                    }
                    TelephonyManager.CALL_STATE_IDLE -> {
                        if (callStartMillis > 0) {
                            val durationSeconds =
                                ((System.currentTimeMillis() - callStartMillis) / 1000L).toInt()
                            callStartMillis = 0L
                            emitCallEnded(durationSeconds)
                        }
                    }
                }
            } catch (_: Exception) {
                // 상태 처리 실패 시 무시
            }
        }
    }

    // ---------------------------------------------------------------- method

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startCallDetection" -> {
                knownPhoneNumbers =
                    call.argument<List<String>>("knownPhoneNumbers") ?: emptyList()
                if (!NativeUtils.hasPermission(context, Manifest.permission.READ_PHONE_STATE)) {
                    result.error(
                        "PERMISSION_DENIED",
                        "READ_PHONE_STATE 권한이 없습니다.",
                        null,
                    )
                    return
                }
                if (attachListener()) {
                    result.success(null)
                } else {
                    result.error("LISTEN_FAILED", "통화 상태 리스너 등록 실패", null)
                }
            }
            "stopCallDetection" -> {
                detachListener()
                result.success(null)
            }
            "transcribeRecording" -> {
                // TODO: 온디바이스 STT(녹음 파일 전사) 미구현.
                //  Dart가 result.error를 null로 처리하므로 에러로 응답한다.
                result.error("NOT_IMPLEMENTED", "온디바이스 STT 미구현", null)
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
        detachListener()
        sink = null
    }

    // ---------------------------------------------------------------- 내부

    private fun attachListener(): Boolean {
        if (listenerAttached) return true
        return try {
            val tm =
                context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            telephonyManager = tm
            tm?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
            listenerAttached = tm != null
            listenerAttached
        } catch (_: Exception) {
            listenerAttached = false
            false
        }
    }

    private fun detachListener() {
        if (!listenerAttached) return
        try {
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        } catch (_: Exception) {
            // 이미 해제된 경우 무시
        }
        listenerAttached = false
        callStartMillis = 0L
    }

    private fun emitCallEnded(durationSeconds: Int) {
        val number = lastPhoneNumber
        lastPhoneNumber = ""
        val event = mapOf<String, Any?>(
            "phoneNumber" to number,
            "durationSeconds" to durationSeconds,
            "recordingFilePath" to null,
            // ID 매핑은 네이티브에 없음 — Dart 측에서 번호로 후처리
            "matchedAccountId" to null,
            "matchedContactId" to null,
            "endedAt" to NativeUtils.isoTimestamp(),
        )
        mainHandler.post { emit(event) }
    }

    private fun emit(event: Map<String, Any?>) {
        val target = sink ?: return
        try {
            target.success(event)
        } catch (_: Exception) {
            // sink 오류 시 이벤트 폐기
        }
    }
}
