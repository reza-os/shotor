package com.example.saraban_sms

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

/** Registered on every FlutterEngine, including the Workmanager headless engine. */
class SarabanSmsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private lateinit var applicationContext: Context
    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingPermission: MethodChannel.Result? = null
    private val requestCode = 9154

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "saraban/native_sms")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        pendingPermission = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        activity = null
        pendingPermission?.error("activity_missing", "صفحه صدور مجوز بسته شد", null)
        pendingPermission = null
    }

    private fun granted(): Boolean = ContextCompat.checkSelfPermission(
        applicationContext, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasSmsPermission" -> result.success(granted())
            "requestSmsPermission" -> {
                if (granted()) { result.success(true); return }
                val host = activity
                if (host == null) {
                    result.error("foreground_required", "مجوز پیامک را از داخل برنامه بدهید", null)
                    return
                }
                if (pendingPermission != null) {
                    result.error("busy", "درخواست مجوز در حال انجام است", null)
                    return
                }
                pendingPermission = result
                ActivityCompat.requestPermissions(host,
                    arrayOf(Manifest.permission.SEND_SMS), requestCode)
            }
            "sendSms" -> {
                if (!granted()) {
                    result.error("sms_permission", "مجوز ارسال پیامک فعال نیست", null)
                    return
                }
                val number = call.argument<String>("phoneNumber")?.trim().orEmpty()
                val body = call.argument<String>("message")?.trim().orEmpty()
                if (number.isEmpty() || body.isEmpty() || !Regex("^\\+?[0-9]{5,15}$").matches(number)) {
                    result.error("invalid_sms", "شماره یا متن پیامک نامعتبر است", null)
                    return
                }
                try {
                    @Suppress("DEPRECATION")
                    val manager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        applicationContext.getSystemService(SmsManager::class.java)
                    } else {
                        SmsManager.getDefault()
                    } ?: throw IllegalStateException("سرویس SMS موجود نیست")
                    val parts = manager.divideMessage(body)
                    if (parts.size <= 1) {
                        manager.sendTextMessage(number, null, body, null, null)
                    } else {
                        manager.sendMultipartTextMessage(number, null, parts, null, null)
                    }
                    // Accepted by Android SMS stack; delivery on carrier not guaranteed.
                    result.success(true)
                } catch (error: Exception) {
                    result.error("send_failed", error.message ?: "ارسال پیامک انجام نشد", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(
        code: Int, permissions: Array<out String>, grantResults: IntArray
    ): Boolean {
        if (code != requestCode) return false
        pendingPermission?.success(grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }
}
