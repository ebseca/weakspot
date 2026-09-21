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
 *
 * **The swap happens in [onStop], never while the app is on screen.** The
 * running task was launched *through* one of those aliases, and disabling
 * a component the current task is built on makes ActivityManager finish
 * the task — the app vanishes mid-tap and reads as a crash. It is not one:
 * nothing throws, and nothing reaches the crash log. `DONT_KILL_APP`
 * spares the process but not the task, so the only reliable fix is to wait
 * until the app is off screen. Waiting until [onStop] is what every app
 * that ships this feature does.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "com.ebseca.weakspot/launcher_icon"
        const val DEFAULT_ALIAS = "com.ebseca.weakspot.Launcher"
        const val PRO_ALIAS = "com.ebseca.weakspot.LauncherPro"
    }

    /** The icon asked for but not yet applied. Null when nothing is owed. */
    private var pendingPro: Boolean? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        requestIcon(call.argument<Boolean>("pro") == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onStop() {
        super.onStop()
        pendingPro?.let {
            applyIcon(it)
            pendingPro = null
        }
    }

    /**
     * Note what the launcher should show. Applied on the way out.
     *
     * An icon that already matches is dropped rather than queued, so the
     * reconcile every launch does costs nothing and never disturbs a task.
     */
    private fun requestIcon(pro: Boolean) {
        pendingPro = if (showingPro() == pro) null else pro
    }

    private fun applyIcon(pro: Boolean) {
        val wanted = if (pro) PRO_ALIAS else DEFAULT_ALIAS
        val other = if (pro) DEFAULT_ALIAS else PRO_ALIAS

        // Order matters. Enabling first means there is never an instant
        // with no launcher entry at all, which is what makes an app
        // disappear from the home screen instead of changing its icon.
        setEnabled(wanted, true)
        setEnabled(other, false)
    }

    private fun showingPro(): Boolean =
        // The manifest ships the Pro alias disabled, so "never been set"
        // means the everyday icon.
        isEnabled(PRO_ALIAS, byDefault = false)

    private fun isEnabled(alias: String, byDefault: Boolean): Boolean =
        when (packageManager.getComponentEnabledSetting(
            ComponentName(this, alias),
        )) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> byDefault
        }

    private fun setEnabled(alias: String, enabled: Boolean) {
        val state = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }

        // DONT_KILL_APP: without it Android restarts the process outright
        // the moment the component changes.
        packageManager.setComponentEnabledSetting(
            ComponentName(this, alias),
            state,
            PackageManager.DONT_KILL_APP,
        )
    }
}
