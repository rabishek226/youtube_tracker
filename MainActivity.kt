import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {

    private val channel = "youtube_tracker/usage"
    private val youtubePackage = "com.google.android.youtube"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channel
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "openUsageSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    )
                    result.success(null)
                }

                "getUsageSummary" -> {
                    if (!hasUsagePermission()) {
                        result.success(
                            mapOf("hasPermission" to false)
                        )
                    } else {
                        result.success(getUsageSummary())
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsagePermission(): Boolean {
        val appOps = getSystemService(
            Context.APP_OPS_SERVICE
        ) as AppOpsManager

        val mode = if (Build.VERSION.SDK_INT >= 29) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }

        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsageSummary(): Map<String, Any> {

        val now = System.currentTimeMillis()

        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val monthStart = (today.clone() as Calendar).apply {
            set(Calendar.DAY_OF_MONTH, 1)
        }

        val weekStart = (today.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, -6)
        }

        val queryStart = minOf(
            monthStart.timeInMillis,
            weekStart.timeInMillis
        )

        val manager = getSystemService(
            Context.USAGE_STATS_SERVICE
        ) as UsageStatsManager

        val records = manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            queryStart,
            now
        ) ?: emptyList()

        val dailyUsage = mutableMapOf<Long, Long>()

        for (record in records) {

            if (record.packageName != youtubePackage) {
                continue
            }

            val dayStart = Calendar.getInstance().apply {
                timeInMillis = record.beginTime
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis

            dailyUsage[dayStart] =
                (dailyUsage[dayStart] ?: 0L) +
                record.totalTimeInForeground
        }

        fun totalBetween(
            start: Long,
            end: Long
        ): Long {
            return dailyUsage
                .filter { it.key >= start && it.key < end }
                .values.sum()
        }

        val todayUsage = totalBetween(
            today.timeInMillis,
            now + 1
        )

        val weekUsage = totalBetween(
            weekStart.timeInMillis,
            now + 1
        )

        val monthUsage = totalBetween(
            monthStart.timeInMillis,
            now + 1
        )

        val lastSevenDays = (0..6).map { offset ->

            val day = (today.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, offset - 6)
            }

            dailyUsage[day.timeInMillis] ?: 0L
        }

        val daysInMonth =
            today.get(Calendar.DAY_OF_MONTH).coerceAtLeast(1)

        return mapOf(
            "hasPermission" to true,
            "todayMillis" to todayUsage,
            "weekMillis" to weekUsage,
            "monthMillis" to monthUsage,
            "dailyAverageMillis" to monthUsage / daysInMonth,
            "lastSevenDaysMillis" to lastSevenDays
        )
    }
}
