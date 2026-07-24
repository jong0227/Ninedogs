package com.jong0227.ninedogs

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 카톡 등에서 백업 파일(.json)을 "Ninedogs로 열기" 했을 때 그 내용을 받아
 * Flutter 쪽에 넘긴다.
 *
 * 파일을 통째로 읽어 문자열로 전달한다. 백업 파일은 수십 KB 수준이라
 * 메모리에 올려도 문제없다.
 */
class MainActivity : FlutterActivity() {
    private var pendingImport: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 앱이 꺼져 있다가 파일로 열린 경우, 첫 인텐트가 여기 담겨 온다.
        pendingImport = readFrom(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // 한 번 가져가면 비운다. 화면을 되돌아올 때마다
                    // 같은 파일을 다시 묻지 않도록.
                    "takePendingImport" -> {
                        result.success(pendingImport)
                        pendingImport = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 앱이 떠 있는 상태에서 파일이 열린 경우. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readFrom(intent)?.let { pendingImport = it }
    }

    private fun readFrom(intent: Intent?): String? {
        val uri: Uri? = when (intent?.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null

        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                stream.bufferedReader().readText()
            }
        } catch (e: Exception) {
            // 읽지 못하면 조용히 넘어간다. 화면에서 안내할 방법이 없다.
            null
        }
    }

    private companion object {
        const val CHANNEL = "ninedogs/import"
    }
}
