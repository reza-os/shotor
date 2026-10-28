package com.example.saraban_app

import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiInfo
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.provider.Settings
import android.provider.DocumentsContract
import android.net.Uri
import android.app.Activity
import android.database.Cursor
import io.flutter.plugin.common.MethodCall
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "saraban/wifi"
    private val backupChannelName = "saraban/portable_storage"
    private val directoryRequest = 7743
    private val folderPrefs = "saraban_portable_folder_v15"
    private var pendingDirectoryResult: MethodChannel.Result? = null

    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configurePortableStorage(flutterEngine.dartExecutor.binaryMessenger)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCurrentWifiSsid" -> {
                    val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                    val ssid = try {
                        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        val caps = manager.getNetworkCapabilities(manager.activeNetwork)
                        val activeInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            caps?.transportInfo as? WifiInfo
                        } else null
                        @Suppress("DEPRECATION")
                        val legacy = wifiManager.connectionInfo
                        (activeInfo?.ssid ?: legacy?.ssid)?.trim('"')
                    } catch (_: Exception) { null }
                    result.success(if (ssid == null || ssid == "<unknown ssid>" || ssid == "0x") null else ssid)
                }

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

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != directoryRequest) return
        val pending = pendingDirectoryResult ?: return
        pendingDirectoryResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending.success(false)
            return
        }
        try {
            contentResolver.takePersistableUriPermission(
                uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            ensureAppFolders(uri)
            getSharedPreferences(folderPrefs, Context.MODE_PRIVATE).edit()
                .putString("parent_uri", uri.toString()).apply()
            pending.success(true)
        } catch (error: Exception) {
            pending.error("folder_error", "امکان ساخت پوشه در محل انتخابی وجود ندارد: ${error.message}", null)
        }
    }

    private fun configuredParent(): Uri? {
        val value = getSharedPreferences(folderPrefs, Context.MODE_PRIVATE)
            .getString("parent_uri", null) ?: return null
        return Uri.parse(value)
    }

    private fun children(parentTree: Uri, dir: Uri): List<Pair<String, Uri>> {
        val result = mutableListOf<Pair<String, Uri>>()
        val childUri = DocumentsContract.buildChildDocumentsUriUsingTree(
            parentTree, DocumentsContract.getDocumentId(dir))
        val projection = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME)
        contentResolver.query(childUri, projection, null, null, null)?.use { cursor ->
            val id = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val name = cursor.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            while (cursor.moveToNext()) {
                val uri = DocumentsContract.buildDocumentUriUsingTree(parentTree, cursor.getString(id))
                result.add(cursor.getString(name) to uri)
            }
        }
        return result
    }

    private fun getOrCreateFolder(tree: Uri, parent: Uri, name: String): Uri {
        val found = children(tree, parent).firstOrNull { it.first == name }
        if (found != null) return found.second
        return DocumentsContract.createDocument(contentResolver, parent,
            DocumentsContract.Document.MIME_TYPE_DIR, name)
            ?: throw IllegalStateException("ساخت پوشه $name ناموفق بود")
    }

    private fun ensureAppFolders(tree: Uri): Map<String, Uri> {
        val root = DocumentsContract.buildDocumentUriUsingTree(tree,
            DocumentsContract.getTreeDocumentId(tree))
        val shotor = getOrCreateFolder(tree, root, "Shotor")
        return mapOf("photos" to getOrCreateFolder(tree, shotor, "عکس‌ها"),
            "backups" to getOrCreateFolder(tree, shotor, "فایل‌های بک‌آپ"))
    }

    private fun writeManagedCopy(folder: String, fileName: String, sourcePath: String): String {
        if (folder != "photos" && folder != "backups") throw IllegalArgumentException("folder")
        if (!Regex("^[a-zA-Z0-9_.-]{1,140}$").matches(fileName) ||
            fileName.startsWith('.')) throw IllegalArgumentException("fileName")
        val file = File(sourcePath)
        if (!file.isFile) throw IllegalArgumentException("Source file not found")
        val tree = configuredParent() ?: throw IllegalStateException("پوشه بک‌آپ انتخاب نشده است")
        val folderUri = ensureAppFolders(tree)[folder] ?: throw IllegalStateException("Folder unavailable")
        // Never overwrite an earlier backup; each export has a unique filename.
        val old = children(tree, folderUri).firstOrNull { it.first == fileName }
        if (old != null) {
            if (!DocumentsContract.deleteDocument(contentResolver, old.second))
                throw IllegalStateException("File cannot be replaced")
        }
        val mime = when {
            fileName.endsWith(".zip") -> "application/zip"
            fileName.endsWith(".png") -> "image/png"
            fileName.endsWith(".webp") -> "image/webp"
            else -> "image/jpeg"
        }
        val target = DocumentsContract.createDocument(contentResolver, folderUri, mime, fileName)
            ?: throw IllegalStateException("Cannot create file")
        try {
            contentResolver.openOutputStream(target, "w")?.use { output ->
                file.inputStream().use { input -> input.copyTo(output, bufferSize = 65536) }
            } ?: throw IllegalStateException("Cannot write target")
        } catch (error: Exception) {
            DocumentsContract.deleteDocument(contentResolver, target)
            throw error
        }
        return target.toString()
    }

    private fun configurePortableStorage(binaryMessenger: io.flutter.plugin.common.BinaryMessenger) {
        MethodChannel(binaryMessenger, backupChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasFolder" -> {
                    val uri = configuredParent()
                    val granted = uri != null && contentResolver.persistedUriPermissions.any {
                        it.uri == uri && it.isReadPermission && it.isWritePermission
                    }
                    result.success(granted)
                }
                "selectFolder" -> {
                    if (pendingDirectoryResult != null) {
                        result.error("busy", "انتخاب پوشه در حال انجام است", null)
                    } else {
                        pendingDirectoryResult = result
                        try {
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            }
                            startActivityForResult(intent, directoryRequest)
                        } catch (error: Exception) {
                            pendingDirectoryResult = null
                            result.error("folder_picker", error.message, null)
                        }
                    }
                }
                "copyFile" -> {
                    val folder = call.argument<String>("folder") ?: ""
                    val name = call.argument<String>("name") ?: ""
                    val path = call.argument<String>("path") ?: ""
                    Thread {
                        try {
                            val uri = writeManagedCopy(folder, name, path)
                            runOnUiThread { result.success(uri) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("copy_failed", error.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
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
