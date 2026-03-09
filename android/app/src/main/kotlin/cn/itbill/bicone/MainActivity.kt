package cn.itbill.bicone

import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.itbill.bicone/media_muxer")
            .setMethodCallHandler { call, result ->
                if (call.method == "mergeStreams") {
                    val videoPath = call.argument<String>("videoPath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (videoPath == null || audioPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        try {
                            withContext(Dispatchers.IO) {
                                MediaMuxerHelper.mergeStreams(videoPath, audioPath, outputPath)
                            }
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("MERGE_FAILED", e.message, null)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bicone/notification_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openChannelSettings") {
                    val channelId = call.argument<String>("channelId")
                    if (channelId != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                        }
                        startActivity(intent)
                        result.success(null)
                    } else {
                        result.error("UNSUPPORTED", "Requires Android O or above", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
