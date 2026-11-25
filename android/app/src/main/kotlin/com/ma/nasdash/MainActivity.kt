package com.ma.nasdash

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.provider.Settings
import android.view.WindowManager
import androidx.annotation.NonNull
import com.ma.nasdash.smb.SmbManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.bouncycastle.jce.provider.BouncyCastleProvider
import java.security.Security

class MainActivity : FlutterFragmentActivity() {
    private val SMB_CHANNEL = "com.ma.nasdash/smb"
    private val DEVICE_CHANNEL = "com.ma.nasdash/device"
    private lateinit var smbManager: SmbManager
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        init {
            try {
                // Remove Android's stripped BC provider and insert complete BouncyCastle with MD4
                Security.removeProvider("BC")
                Security.insertProviderAt(BouncyCastleProvider(), 1)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Ensure provider is installed
        try {
            if (Security.getProvider("BC") !is BouncyCastleProvider) {
                Security.removeProvider("BC")
                Security.insertProviderAt(BouncyCastleProvider(), 1)
            }
        } catch (_: Exception) {}

        smbManager = SmbManager(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMB_CHANNEL).setMethodCallHandler { call, result ->
            val host = call.argument<String>("host") ?: ""
            val share = call.argument<String>("share") ?: ""
            val path = call.argument<String>("path") ?: ""
            val username = call.argument<String>("username")
            val password = call.argument<String>("password")
            val domain = call.argument<String>("domain")

            when (call.method) {
                "listFiles" -> {
                    scope.launch {
                        try {
                            val files = smbManager.listFiles(host, share, path, username, password, domain)
                            result.success(files)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "createFolder" -> {
                    val url = call.argument<String>("url") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.createFolder(url, username, password, domain)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "rename" -> {
                    val sourceUrl = call.argument<String>("sourceUrl") ?: ""
                    val newName = call.argument<String>("newName") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.rename(sourceUrl, newName, username, password, domain)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "delete" -> {
                    val url = call.argument<String>("url") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.delete(url, username, password, domain)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "copy" -> {
                    val sourceUrl = call.argument<String>("sourceUrl") ?: ""
                    val destUrl = call.argument<String>("destUrl") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.copy(sourceUrl, destUrl, username, password, domain)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "move" -> {
                    val sourceUrl = call.argument<String>("sourceUrl") ?: ""
                    val destUrl = call.argument<String>("destUrl") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.move(sourceUrl, destUrl, username, password, domain)
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "download" -> {
                    val remoteUrl = call.argument<String>("remoteUrl") ?: ""
                    val localPath = call.argument<String>("localPath") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.download(remoteUrl, localPath, username, password, domain) { _, _ -> }
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                "upload" -> {
                    val localPath = call.argument<String>("localPath") ?: ""
                    val remoteUrl = call.argument<String>("remoteUrl") ?: ""
                    scope.launch {
                        try {
                            val ok = smbManager.upload(localPath, remoteUrl, username, password, domain) { _, _ -> }
                            result.success(ok)
                        } catch (e: Exception) {
                            result.error("SMB_ERROR", e.localizedMessage, e.stackTraceToString())
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    runOnUiThread {
                        if (enable) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(true)
                }
                "setScreenBrightness" -> {
                    val brightness = call.argument<Double>("brightness")?.toFloat()
                        ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    runOnUiThread {
                        val lp = window.attributes
                        lp.screenBrightness = brightness
                        window.attributes = lp
                    }
                    result.success(true)
                }
                "dimScreenBrightness" -> {
                    val factor = (call.argument<Double>("factor") ?: 0.90).toFloat()
                    val minBrightness = (call.argument<Double>("minBrightness") ?: 0.02).toFloat()
                    runOnUiThread {
                        val lp = window.attributes
                        val currentNormalized = if (lp.screenBrightness >= 0f) {
                            lp.screenBrightness
                        } else {
                            val sysVal = try {
                                Settings.System.getInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                    128
                                )
                            } catch (_: Exception) {
                                128
                            }
                            sysVal.coerceIn(0, 255) / 255f
                        }
                        lp.screenBrightness =
                            (currentNormalized * factor).coerceIn(minBrightness, 1.0f)
                        window.attributes = lp
                    }
                    result.success(true)
                }
                "getBatteryStatus" -> {
                    try {
                        val bm = getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                        var level = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
                        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        if (level <= 0 && intent != null) {
                            val rawLevel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                            val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                            if (rawLevel >= 0 && scale > 0) {
                                level = (rawLevel * 100) / scale
                            }
                        }
                        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
                                status == BatteryManager.BATTERY_STATUS_FULL
                        result.success(
                            mapOf(
                                "level" to level.coerceIn(0, 100),
                                "isCharging" to isCharging
                            )
                        )
                    } catch (e: Exception) {
                        result.success(mapOf("level" to 100, "isCharging" to false))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
