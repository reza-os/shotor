package com.example.saraban_app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "saraban/wifi"

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openWifiPanel" -> {
                    openWifiPanel()
                    result.success(true)
                }

                "connectToAntennaWifi" -> {
                    val ssid = call.argument<String>("ssid") ?: "Mobile_Antenna_ESP32"
                    val password = call.argument<String>("password") ?: "antenna123"

                    connectToAntennaWifi(
                        ssid = ssid,
                        password = password,
                        result = result
                    )
                }

                "releaseWifiNetwork" -> {
                    releaseWifiNetwork()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openWifiPanel() {
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            Intent(Settings.Panel.ACTION_WIFI)
        } else {
            Intent(Settings.ACTION_WIFI_SETTINGS)
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun connectToAntennaWifi(
        ssid: String,
        password: String,
        result: MethodChannel.Result
    ) {
        val wifiManager =
            applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager

        if (!wifiManager.isWifiEnabled) {
            openWifiPanel()
            result.error(
                "wifi_disabled",
                "WiFi خاموش است. آن را روشن کنید و دوباره اتصال را بزنید.",
                null
            )
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error(
                "unsupported_android",
                "اتصال خودکار SSID در این نسخه Android باید جداگانه پیاده‌سازی شود.",
                null
            )
            return
        }

        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(password)
            .build()

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .setNetworkSpecifier(specifier)
            .build()

        val manager =
            getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        connectivityManager = manager

        releaseWifiNetwork()

        var replied = false

        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                manager.bindProcessToNetwork(network)

                runOnUiThread {
                    if (!replied) {
                        replied = true
                        result.success(true)
                    }
                }
            }

            override fun onUnavailable() {
                runOnUiThread {
                    if (!replied) {
                        replied = true
                        result.error(
                            "wifi_unavailable",
                            "شبکه Mobile_Antenna_ESP32 پیدا نشد یا کاربر اتصال را تأیید نکرد.",
                            null
                        )
                    }
                }
            }

            override fun onLost(network: Network) {
                manager.bindProcessToNetwork(null)
            }
        }

        networkCallback = callback
        manager.requestNetwork(request, callback)
    }

    private fun releaseWifiNetwork() {
        val manager = connectivityManager
            ?: getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        networkCallback?.let {
            try {
                manager.unregisterNetworkCallback(it)
            } catch (_: Exception) {
            }
        }

        networkCallback = null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.bindProcessToNetwork(null)
        }
    }
}
