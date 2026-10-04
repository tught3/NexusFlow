package com.nexusflow.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var smsManager: SmsDetectionManager? = null
    private var kakaoManager: KakaoDetectionManager? = null
    private var callManager: CallDetectionManager? = null
    private var screenshotManager: ScreenshotObserverManager? = null
    private var overlayManager: OverlayManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val appContext = applicationContext

        smsManager = SmsDetectionManager(appContext).also { m ->
            MethodChannel(messenger, "nexusflow/sms")
                .setMethodCallHandler { call, result -> m.handleMethodCall(call, result) }
            EventChannel(messenger, "nexusflow/sms_events").setStreamHandler(m)
        }
        kakaoManager = KakaoDetectionManager(appContext).also { m ->
            MethodChannel(messenger, "nexusflow/kakao")
                .setMethodCallHandler { call, result -> m.handleMethodCall(call, result) }
            EventChannel(messenger, "nexusflow/kakao_events").setStreamHandler(m)
        }
        callManager = CallDetectionManager(appContext).also { m ->
            MethodChannel(messenger, "nexusflow/call")
                .setMethodCallHandler { call, result -> m.handleMethodCall(call, result) }
            EventChannel(messenger, "nexusflow/call_events").setStreamHandler(m)
        }
        screenshotManager = ScreenshotObserverManager(appContext).also { m ->
            MethodChannel(messenger, "nexusflow/screenshot")
                .setMethodCallHandler { call, result -> m.handleMethodCall(call, result) }
            EventChannel(messenger, "nexusflow/screenshot_events").setStreamHandler(m)
        }
        overlayManager = OverlayManager(appContext).also { m ->
            MethodChannel(messenger, "nexusflow/overlay")
                .setMethodCallHandler { call, result -> m.handleMethodCall(call, result) }
            EventChannel(messenger, "nexusflow/overlay_results").setStreamHandler(m)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        smsManager?.stopAll()
        kakaoManager?.stopAll()
        callManager?.stopAll()
        screenshotManager?.stopAll()
        overlayManager?.stopAll()
        smsManager = null
        kakaoManager = null
        callManager = null
        screenshotManager = null
        overlayManager = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
