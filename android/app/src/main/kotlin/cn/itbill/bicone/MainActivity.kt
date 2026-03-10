package cn.itbill.bicone

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

class MainActivity : FlutterActivity() {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private var installPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val INSTALL_PERMISSION_REQUEST_CODE = 1001
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cn.itbill.bicone/install_permission")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canRequestPackageInstalls" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(packageManager.canRequestPackageInstalls())
                        } else {
                            result.success(true)
                        }
                    }
                    "requestInstallPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
                            installPermissionResult = result
                            val intent = Intent(
                                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:$packageName")
                            )
                            startActivityForResult(intent, INSTALL_PERMISSION_REQUEST_CODE)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

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
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == INSTALL_PERMISSION_REQUEST_CODE) {
            val canInstall = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                packageManager.canRequestPackageInstalls()
            } else {
                true
            }
            installPermissionResult?.success(canInstall)
            installPermissionResult = null
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
