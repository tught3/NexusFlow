package com.nexusflow.app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * 카카오톡 알림 수신 서비스.
 * 매니페스트에 BIND_NOTIFICATION_LISTENER_SERVICE 권한으로 등록되며,
 * 수신된 알림을 KakaoDetectionManager 싱글톤으로 전달한다.
 */
class NexusflowNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        try {
            if (sbn?.packageName != KakaoDetectionManager.KAKAO_PACKAGE) return
            val extras = sbn.notification?.extras ?: return
            val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
            val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
            if (title.isNullOrBlank() && text.isNullOrBlank()) return
            KakaoDetectionManager.handleNotification(title, text)
        } catch (_: Exception) {
            // 알림 처리 실패 시 무시
        }
    }
}
