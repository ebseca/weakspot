package com.ebseca.weakspot

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter app, and owns the one thing Flutter cannot do itself:
 * changing which icon the launcher shows.
 *
 * Android has no API for "set my icon". What it has is component enabling,
 * so the manifest declares two `activity-alias` entries pointing at this
 * activity — one with the everyday icon, one with the Pro icon — and this
 * turns one on and the other off.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.ebseca.weakspot/launcher_icon"
        const val DEFAULT_ALIAS = "com.ebseca.weakspot.Launcher"
        const val PRO_ALIAS = "com.ebseca.weakspot.LauncherPro"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        useIcon(call.argument<Boolean>("pro") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun useIcon(pro: Boolean) {
        val wanted = if (pro) PRO_ALIAS else DEFAULT_ALIAS
        val other = if (pro) DEFAULT_ALIAS else PRO_ALIAS

        // Order matters. Enabling first means there is never an instant
        // with no launcher entry at all, which is what makes an app
        // disappear from the home screen instead of changing its icon.
        setEnabled(wanted, true)
        setEnabled(other, false)
    }

    private fun setEnabled(alias: String, enabled: Boolean) {
        val state = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }

        // DONT_KILL_APP: without it Android restarts the process the moment
        // the component changes, so turning Pro on would close the app.
        packageManager.setComponentEnabledSetting(
            ComponentName(this, alias),
            state,
            PackageManager.DONT_KILL_APP,
        )
    }
}
