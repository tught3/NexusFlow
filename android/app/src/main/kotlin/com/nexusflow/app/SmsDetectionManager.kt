package com.nexusflow.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsMessage
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * SMS 감지 매니저.
 * - 채널: nexusflow/sms (method), nexusflow/sms_events (event)
 * - RECEIVER_SMS 브로드캐스트는 startSmsDetection 시점에 동적 등록한다.
 *   (manifest 정적 등록 금지 — Android 13+ SMS 정책 위반 위험)
 */
class SmsDetectionManager(private val context: Context) : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private var knownPhoneNumbers: List<String> = emptyList()
    private var keywords: List<String> = emptyList()
    private var receiverRegistered = false
    private val mainHandler = Handler(Looper.getMainLooper())

    private val smsReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action != SMS_RECEIVED_ACTION) return
            try {
                parseAndEmit(intent)
            } catch (_: Exception) {
                // 파싱 실패 시 이벤트 폐기
            }
        }
    }

    // ---------------------------------------------------------------- method

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startSmsDetection" -> {
                knownPhoneNumbers =
                    call.argument<List<String>>("knownPhoneNumbers") ?: emptyList()
                keywords = call.argument<List<String>>("keywords") ?: emptyList()
                if (!NativeUtils.hasPermission(context, Manifest.permission.RECEIVE_SMS)) {
                    result.error(
                        "PERMISSION_DENIED",
                        "RECEIVE_SMS 권한이 없습니다.",
                        null,
                    )
                    return
                }
                if (startReceiver()) {
                    result.success(null)
                } else {
                    result.error("REGISTER_FAILED", "SMS 리시버 등록 실패", null)
                }
            }
            "stopSmsDetection" -> {
                stopReceiver()
                result.success(null)
            }
            "updatePhoneNumbers" -> {
                knownPhoneNumbers =
                    call.argument<List<String>>("phoneNumbers") ?: emptyList()
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
        stopReceiver()
        sink = null
    }

    // ---------------------------------------------------------------- 내부

    private fun startReceiver(): Boolean {
        if (receiverRegistered) return true
        val filter = IntentFilter(SMS_RECEIVED_ACTION)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // SMS는 다른 앱이 보내는 protected broadcast이므로 EXPORTED로 등록 (정석 패턴)
                context.registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                context.registerReceiver(smsReceiver, filter)
            }
            receiverRegistered = true
            true
        } catch (_: Exception) {
            receiverRegistered = false
            false
        }
    }

    private fun stopReceiver() {
        if (!receiverRegistered) return
        try {
            context.unregisterReceiver(smsReceiver)
        } catch (_: Exception) {
            // 이미 해제된 경우 무시
        }
        receiverRegistered = false
    }

    private fun parseAndEmit(intent: Intent) {
        val extras = intent.extras ?: return
        val pdus = extras.get("pdus") as? Array<*> ?: return
        val format = extras.getString("format")

        var sender = ""
        val body = StringBuilder()
        for (pdu in pdus) {
            val bytes = pdu as? ByteArray ?: continue
            val message: SmsMessage? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                SmsMessage.createFromPdu(bytes, format)
            } else {
                @Suppress("DEPRECATION")
                SmsMessage.createFromPdu(bytes)
            }
            if (message == null) continue
            if (sender.isEmpty()) sender = message.originatingAddress ?: ""
            body.append(message.messageBody ?: "")
        }
        if (sender.isEmpty() && body.isEmpty()) return

        val fullBody = body.toString()
        val matchedNumbers = knownPhoneNumbers.filter { numbersMatch(sender, it) }
        val matchedKeywords = keywords.filter { fullBody.contains(it, ignoreCase = true) }
        // 거래처 번호 또는 키워드 매칭된 SMS만 이벤트 발생
        if (matchedNumbers.isEmpty() && matchedKeywords.isEmpty()) return

        val event = mapOf<String, Any?>(
            "sender" to sender,
            "body" to fullBody,
            // ID 매핑은 네이티브에 없음 — Dart 측에서 번호/키워드로 후처리
            "matchedAccountId" to null,
            "matchedContactId" to null,
            "matchedKeywords" to matchedKeywords,
            "receivedAt" to NativeUtils.isoTimestamp(),
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

    /** 국가코드/하이픈 차이를 흡수하는 전화번호 매칭 */
    private fun numbersMatch(a: String, b: String): Boolean {
        val da = a.filter { it.isDigit() }
        val db = b.filter { it.isDigit() }
        if (da.isEmpty() || db.isEmpty()) return false
        return da.endsWith(db) || db.endsWith(da)
    }

    companion object {
        private const val SMS_RECEIVED_ACTION = "android.provider.Telephony.SMS_RECEIVED"
    }
}
