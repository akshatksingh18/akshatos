package com.akshat.squatreminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Exact alarms are wiped on reboot. If the chain was running when the phone
 * went down, re-arm it — phase resets to "45 minutes from reboot" rather
 * than trying to preserve the original schedule.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (ReminderPrefs.isRunning(context)) {
            ReminderScheduler.scheduleNext(context)
        }
    }
}
