package com.example.saraban_app

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "saraban/native_sms"
    private val smsPermissionRequestCode = 7001

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> {
                    result.success(hasSmsPermission())
                }

                "requestSmsPermission" -> {
                    requestSmsPermission(result)
                }

                "sendSms" -> {
                    val phoneNumber = call.argument<String>("phoneNumber")?.trim() ?: ""
                    val message = call.argument<String>("message")?.trim() ?: ""

                    if (phoneNumber.isEmpty()) {
                        result.error(
                            "EMPTY_PHONE",
                            "شماره مقصد پیامک خالی است.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (message.isEmpty()) {
                        result.error(
                            "EMPTY_MESSAGE",
                            "متن پیامک خالی است.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    if (!hasSmsPermission()) {
                        result.error(
                            "NO_SMS_PERMISSION",
                            "مجوز ارسال پیامک داده نشده است.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        sendNativeSms(
                            phoneNumber = phoneNumber,
                            message = message
                        )

                        result.success(true)
                    } catch (e: Exception) {
                        result.error(
                            "SMS_SEND_FAILED",
                            e.message ?: "خطای نامشخص در ارسال پیامک",
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasSmsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            true
        } else {
            checkSelfPermission(Manifest.permission.SEND_SMS) ==
                    PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }

        if (pendingPermissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_RUNNING",
                "درخواست مجوز پیامک در حال انجام است.",
                null
            )
            return
        }

        pendingPermissionResult = result

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            requestPermissions(
                arrayOf(Manifest.permission.SEND_SMS),
                smsPermissionRequestCode
            )
        } else {
            pendingPermissionResult?.success(true)
            pendingPermissionResult = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == smsPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED

            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun sendNativeSms(
        phoneNumber: String,
        message: String
    ) {
        val smsManager = getSmsManager()

        val parts = smsManager.divideMessage(message)

        if (parts.size <= 1) {
            smsManager.sendTextMessage(
                phoneNumber,
                null,
                message,
                null,
                null
            )
        } else {
            smsManager.sendMultipartTextMessage(
                phoneNumber,
                null,
                ArrayList(parts),
                null,
                null
            )
        }
    }

    private fun getSmsManager(): SmsManager {
        return if (Build.VERSION.SDK_INT >= 31) {
            getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
    }
}