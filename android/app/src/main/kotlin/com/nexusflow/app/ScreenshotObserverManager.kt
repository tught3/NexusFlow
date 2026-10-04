package com.nexusflow.app

import android.content.Context
import android.os.Environment
import android.os.FileObserver
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 스크린샷 감지 매니저.
 * - 채널: nexusflow/screenshot (method), nexusflow/screenshot_events (event)
 * - FileObserver로 Pictures/Screenshots 폴더 감시 (CREATE/CLOSE_WRITE/MOVED_TO).
 * - OCR은 네이티브에서 하지 않는다: ocrText는 빈 문자열, matchedKeywords는 빈 리스트.
 *   (관련성 판별/OCR은 Dart 측 OcrService에서 후처리)
 */
class ScreenshotObserverManager(private val context: Context) : EventChannel.StreamHandler {

    private var sink: EventChannel.EventSink? = null

    // 관련성 판별은 Dart 측이지만, 추후 네이티브 매칭 대비해 키워드 목록만 보관
    @Suppress("unused")
    private var keywords: List<String> = emptyList()

    @Suppress("unused")
    private var accountNames: List<String> = emptyList()

    @Suppress("unused")
    private var contactNames: List<String> = emptyList()

    private var observer: FileObserver? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val lastEmitAt = HashMap<String, Long>()

    // ---------------------------------------------------------------- method

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDetection" -> {
                keywords = call.argument<List<String>>("keywords") ?: emptyList()
                accountNames = call.argument<List<String>>("accountNames") ?: emptyList()
                contactNames = call.argument<List<String>>("contactNames") ?: emptyList()
                if (startWatching()) {
                    result.success(null)
                } else {
                    // Q+ 저장소 제한 등으로 감시 시작 실패 가능
                    result.error("START_FAILED", "스크린샷 폴더 감시 시작 실패", null)
                }
            }
            "stopDetection" -> {
                stopWatching()
                result.success(null)
            }
            "updateKeywords" -> {
                keywords = call.argument<List<String>>("keywords") ?: emptyList()
                accountNames = call.argument<List<String>>("accountNames") ?: emptyList()
                contactNames = call.argument<List<String>>("contactNames") ?: emptyList()
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
        stopWatching()
        sink = null
    }

    // ---------------------------------------------------------------- 내부

    @Suppress("DEPRECATION")
    private fun screenshotsDir(): File {
        val pictures =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
        return File(pictures, "Screenshots")
    }

    private fun startWatching(): Boolean {
        if (observer != null) return true
        return try {
            val dir = screenshotsDir()
            // Screenshots 폴더가 아직 없으면 상위 Pictures 폴더를 감시 (폴더 생성은 하지 않음)
            val watchDir = if (dir.exists()) dir else dir.parentFile ?: dir
            observer = object : FileObserver(watchDir, WATCH_MASK) {
                override fun onEvent(event: Int, path: String?) {
                    if (path == null) return
                    try {
                        val fileName = path.substringAfterLast('/')
                        val ext = fileName.substringAfterLast('.', "").lowercase()
                        if (ext !in IMAGE_EXTENSIONS) return
                        // 감시 폴더 기준 상대 경로 → 절대 경로 변환
                        val fullPath = File(watchDir, path).absolutePath
                        handleScreenshotFile(fullPath)
                    } catch (_: Exception) {
                        // 이벤트 처리 실패 시 무시
                    }
                }
            }
            observer?.startWatching()
            true
        } catch (_: Exception) {
            observer = null
            false
        }
    }

    private fun stopWatching() {
        try {
            observer?.stopWatching()
        } catch (_: Exception) {
            // 이미 중지된 경우 무시
        }
        observer = null
    }

    /** 동일 파일 중복 이벤트(CREATE→CLOSE_WRITE 등)를 2초 디바운스 */
    private fun handleScreenshotFile(fullPath: String) {
        val now = System.currentTimeMillis()
        synchronized(lastEmitAt) {
            val last = lastEmitAt[fullPath]
            if (last != null && now - last < DEBOUNCE_MS) return
            if (lastEmitAt.size > MAX_TRACKED_PATHS) lastEmitAt.clear()
            lastEmitAt[fullPath] = now
        }
        val event = mapOf<String, Any?>(
            "imagePath" to fullPath,
            "ocrText" to "", // OCR은 Dart OcrService에서 수행
            "matchedKeywords" to emptyList<String>(), // 관련성 판별도 Dart 측
            "detectedAt" to NativeUtils.isoTimestamp(),
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

    companion object {
        private val WATCH_MASK =
            FileObserver.CREATE or FileObserver.CLOSE_WRITE or FileObserver.MOVED_TO
        private val IMAGE_EXTENSIONS = setOf("jpg", "jpeg", "png", "webp")
        private const val DEBOUNCE_MS = 2000L
        private const val MAX_TRACKED_PATHS = 64
    }
}
