package com.akshat.squatreminder

import android.content.Context

private const val PREFS_NAME = "squat_prefs"
private const val KEY_IS_RUNNING = "is_running"
private const val KEY_NEXT_TRIGGER_AT = "next_trigger_at"
private const val KEY_INTERVAL_MINUTES = "interval_minutes"
const val DEFAULT_INTERVAL_MINUTES = 45

object ReminderPrefs {

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun isRunning(context: Context): Boolean =
        prefs(context).getBoolean(KEY_IS_RUNNING, false)

    fun setRunning(context: Context, running: Boolean) {
        prefs(context).edit().putBoolean(KEY_IS_RUNNING, running).apply()
    }

    fun nextTriggerAt(context: Context): Long =
        prefs(context).getLong(KEY_NEXT_TRIGGER_AT, 0L)

    fun setNextTriggerAt(context: Context, atMillis: Long) {
        prefs(context).edit().putLong(KEY_NEXT_TRIGGER_AT, atMillis).apply()
    }

    fun intervalMinutes(context: Context): Int =
        prefs(context).getInt(KEY_INTERVAL_MINUTES, DEFAULT_INTERVAL_MINUTES)

    fun setIntervalMinutes(context: Context, minutes: Int) {
        prefs(context).edit().putInt(KEY_INTERVAL_MINUTES, minutes).apply()
    }
}
