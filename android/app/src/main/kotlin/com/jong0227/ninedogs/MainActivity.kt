package com.jong0227.ninedogs

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 카톡 등에서 백업 파일(.json)을 "Ninedogs로 열기" 했을 때 그 내용을 받아
 * Flutter 쪽에 넘긴다.
 *
 * 파일을 통째로 읽어 문자열로 전달한다. 백업 파일은 수십 KB 수준이라
 * 메모리에 올려도 문제없다.
 */
// local_auth 는 생체인증 다이얼로그를 띄우려면 FragmentActivity 를 요구한다.
// 그래서 FlutterActivity 가 아니라 FlutterFragmentActivity 를 상속한다.
class MainActivity : FlutterFragmentActivity() {
    private var pendingImport: String? = null

    // 설정 화면의 "가져오기" 버튼에서 직접 파일을 고를 때 쓴다. 시스템 파일
    // 선택기는 비동기(activity result)라, 고르는 동안 기다릴 Flutter 쪽
    // result 콜백을 여기 잠깐 들고 있는다.
    private var pendingPickResult: MethodChannel.Result? = null

    private val pickBackupLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            val result = pendingPickResult
            pendingPickResult = null
            if (uri == null) {
                // 사용자가 취소함
                result?.success(null)
                return@registerForActivityResult
            }
            val content = try {
                contentResolver.openInputStream(uri)?.use { it.bufferedReader().readText() }
            } catch (e: Exception) {
                null
            }
            result?.success(content)
        }

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
                    // 설정 화면 "가져오기" 버튼: 시스템 파일 선택기를 띄운다.
                    "pickBackupFile" -> {
                        pendingPickResult = result
                        pickBackupLauncher.launch(arrayOf("application/json"))
                    }
                    else -> result.notImplemented()
                }
            }

        // 안 쓰는 구독 찾기(선택 기능). 켜지 않으면 아무것도 읽지 않는다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasUsagePermission())
                    // 이 권한은 일반 권한 창으로 못 받는다. 설정 화면까지만
                    // 데려다주고 켜는 건 사용자가 직접 한다.
                    "openSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    }
                    "lastUsed" -> {
                        val packages = call.argument<List<String>>("packages")
                        if (packages == null) {
                            result.error("no_packages", "packages 가 필요합니다", null)
                        } else {
                            result.success(lastUsedMillis(packages))
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // 앱 업데이트: 내려받은 APK 를 안드로이드 설치 화면으로 넘긴다.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("no_path", "path 가 필요합니다", null)
                        } else {
                            try {
                                installApk(path)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("install_failed", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** 사용 정보 접근이 켜져 있는지. */
    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.unsafeCheckOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /**
     * 각 패키지를 마지막으로 쓴 시각(epoch millis). 기록이 없으면 넣지 않는다.
     *
     * 최근 1년치만 본다. 그보다 오래된 건 시스템도 잘 갖고 있지 않고,
     * "1년 넘게 안 썼다"까지만 알아도 판단에는 충분하다.
     */
    private fun lastUsedMillis(packages: List<String>): Map<String, Long> {
        if (!hasUsagePermission()) return emptyMap()

        val manager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val yearAgo = now - 365L * 24 * 60 * 60 * 1000

        val stats = manager.queryAndAggregateUsageStats(yearAgo, now)
        val wanted = packages.toSet()
        val result = mutableMapOf<String, Long>()

        for ((pkg, stat) in stats) {
            if (pkg !in wanted) continue
            // 한 번도 안 쓴 앱은 0 이 들어온다. 그건 기록이 없는 것과 같다.
            if (stat.lastTimeUsed <= 0) continue
            result[pkg] = stat.lastTimeUsed
        }
        return result
    }

    /**
     * APK 파일을 안드로이드 패키지 설치기로 넘긴다.
     *
     * 파일 경로를 직접 넘기면 Android 7+ 는 막으므로 FileProvider 로 content
     * URI 를 만들어 읽기 권한과 함께 준다. 설치기가 뜨고, 사용자가 "설치"를
     * 눌러야 진행된다. "출처를 알 수 없는 앱" 허용은 시스템이 알아서 묻는다.
     */
    private fun installApk(path: String) {
        val file = File(path)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
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
        const val INSTALL_CHANNEL = "ninedogs/install"
        const val USAGE_CHANNEL = "ninedogs/usage"
    }
}
