package com.nexusflow.app

import android.content.Context
import android.content.pm.PackageManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/** 감지 매니저 공통 유틸 */
internal object NativeUtils {

    /** minSdk 무관하게 동작하는 권한 확인 (Context.checkSelfPermission은 API 23+) */
    fun hasPermission(context: Context, permission: String): Boolean {
        return try {
            context.packageManager.checkPermission(permission, context.packageName) ==
                PackageManager.PERMISSION_GRANTED
        } catch (_: Exception) {
            false
        }
    }

    /** ISO8601 UTC 타임스탬프 (java.time 미사용 — minSdk 호환) */
    fun isoTimestamp(): String {
        val format = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(Date())
    }
}
