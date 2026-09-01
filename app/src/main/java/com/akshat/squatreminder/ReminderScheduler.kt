package com.akshat.squatreminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

/**
 * Owns every AlarmManager touchpoint. The chain is self-rescheduling
 * (ReminderReceiver calls scheduleNext() again after each fire) rather than
 * a single setRepeating() call, so it can stop cleanly and stays exact.
 *
 * The interval is read fresh from ReminderPrefs on every call rather than
 * cached, so changing it in the UI takes effect on the *next* scheduled
 * alarm without needing to cancel/restart the chain.
 */
object ReminderScheduler {

    private fun alarmIntent(context: Context): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun scheduleNext(context: Context, fromMillis: Long = System.currentTimeMillis()) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intervalMillis = ReminderPrefs.intervalMinutes(context) * 60L * 1000L
        val triggerAt = fromMillis + intervalMillis
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            alarmIntent(context)
        )
        ReminderPrefs.setNextTriggerAt(context, triggerAt)
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(alarmIntent(context))
        ReminderPrefs.setNextTriggerAt(context, 0L)
    }

    fun start(context: Context) {
        ReminderPrefs.setRunning(context, true)
        scheduleNext(context)
    }

    fun stop(context: Context) {
        ReminderPrefs.setRunning(context, false)
        cancel(context)
    }
}
