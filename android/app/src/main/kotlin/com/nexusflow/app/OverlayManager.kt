package com.nexusflow.app

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 플로팅 오버레이 매니저.
 * - 채널: nexusflow/overlay (method), nexusflow/overlay_results (event)
 * - WindowManager(TYPE_APPLICATION_OVERLAY, FLAG_NOT_FOCUSABLE)로 다른 앱 위에 표시.
 * - 흰 반투명 카드: 제목 + sourceType + [저장][나중에] 버튼.
 * - 버튼 클릭 시 overlay_results에 {action: 'save'|'dismiss'} emit 후 오버레이 제거.
 */
class OverlayManager(private val context: Context) : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null
    private var overlayView: LinearLayout? = null
    private var windowManager: WindowManager? = null
    private var pendingExtractedData: Any? = null
    private var lastSourceType = ""
    private val mainHandler = Handler(Looper.getMainLooper())

    // ---------------------------------------------------------------- method

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasOverlayPermission" -> result.success(hasOverlayPermission())
            "requestOverlayPermission" -> {
                // 오버레이 권한 설정 화면 (패키지 지정) 으로 이동
                try {
                    context.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${context.packageName}"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                } catch (_: Exception) {
                    // 설정 화면 실행 실패 시 무시
                }
                result.success(null)
            }
            "showOverlay" -> {
                val title = call.argument<String>("title") ?: ""
                val sourceType = call.argument<String>("sourceType") ?: ""
                val extractedData = call.argument<Any?>("extractedData")
                showOverlay(title, sourceType, extractedData, result)
            }
            "hideOverlay" -> {
                hideOverlay()
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
        hideOverlay()
        sink = null
    }

    // ---------------------------------------------------------------- 내부

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else {
            true // API 23 미만은 설치 시 부여
        }
    }

    private fun overlayWindowType(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
    }

    private fun showOverlay(
        title: String,
        sourceType: String,
        extractedData: Any?,
        result: MethodChannel.Result,
    ) {
        if (!hasOverlayPermission()) {
            result.error(
                "NO_OVERLAY_PERMISSION",
                "오버레이 권한(SYSTEM_ALERT_WINDOW)이 없습니다.",
                null,
            )
            return
        }
        try {
            hideOverlay() // 기존 오버레이 정리
            val wm =
                context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm
            lastSourceType = sourceType
            pendingExtractedData = extractedData

            val density = context.resources.displayMetrics.density
            fun dp(value: Int): Int = (value * density + 0.5f).toInt()

            // 흰 반투명 라운드 카드
            val card = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                background = GradientDrawable().apply {
                    cornerRadius = dp(16).toFloat()
                    setColor(0xF2FFFFFF.toInt())
                }
                setPadding(dp(16), dp(12), dp(16), dp(12))
            }

            // 헤더: 제목(좌) + sourceType(우측 상단 작은 텍스트)
            val header = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
            }
            val titleView = TextView(context).apply {
                text = title
                setTextColor(Color.parseColor("#222222"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
                setTypeface(typeface, Typeface.BOLD)
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f,
                )
            }
            val sourceView = TextView(context).apply {
                text = sourceType
                setTextColor(Color.parseColor("#888888"))
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 11f)
            }
            header.addView(titleView)
            header.addView(sourceView)
            card.addView(header)

            // 버튼 행: [저장] [나중에]
            val buttonRow = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(10), 0, 0)
            }
            val saveButton = Button(context).apply {
                text = "저장"
                setOnClickListener { emitResult(ACTION_SAVE) }
            }
            val dismissButton = Button(context).apply {
                text = "나중에"
                setOnClickListener { emitResult(ACTION_DISMISS) }
            }
            buttonRow.addView(
                saveButton,
                LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f,
                ).apply { marginEnd = dp(6) },
            )
            buttonRow.addView(
                dismissButton,
                LinearLayout.LayoutParams(
                    0,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    1f,
                ).apply { marginStart = dp(6) },
            )
            card.addView(buttonRow)

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                overlayWindowType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT,
            ).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                x = 0
                y = dp(96)
            }

            wm.addView(card, params)
            overlayView = card
            result.success(null)
        } catch (e: Exception) {
            result.error("OVERLAY_FAILED", "오버레이 표시 실패: ${e.message}", null)
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        overlayView = null
        pendingExtractedData = null
        try {
            windowManager?.removeView(view)
        } catch (_: Exception) {
            // 이미 제거된 경우 무시
        }
    }

    /** 버튼 클릭 결과 emit 후 오버레이 제거 */
    private fun emitResult(action: String) {
        val event = HashMap<String, Any?>()
        event["action"] = action
        event["sourceType"] = lastSourceType
        if (action == ACTION_SAVE) {
            val data = pendingExtractedData
            if (data is Map<*, *>) event["extractedData"] = data
        }
        mainHandler.post {
            val target = sink
            if (target != null) {
                try {
                    target.success(event)
                } catch (_: Exception) {
                    // sink 오류 시 이벤트 폐기
                }
            }
            hideOverlay()
        }
    }

    companion object {
        const val ACTION_SAVE = "save"
        const val ACTION_DISMISS = "dismiss"
    }
}
