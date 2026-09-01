package com.akshat.squatreminder

import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {

    private val notificationPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    SquatReminderScreen()
                }
            }
        }
    }
}

@Composable
private fun SquatReminderScreen() {
    val context = LocalContext.current
    var isRunning by remember { mutableStateOf(ReminderPrefs.isRunning(context)) }
    var nextTriggerAt by remember { mutableStateOf(ReminderPrefs.nextTriggerAt(context)) }
    var intervalText by remember {
        mutableStateOf(ReminderPrefs.intervalMinutes(context).toString())
    }
    var showExactAlarmDialog by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = if (isRunning) "Running" else "Not running",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        if (isRunning && nextTriggerAt > 0L) {
            val formatted = remember(nextTriggerAt) {
                SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(nextTriggerAt))
            }
            Text(text = "Next reminder at $formatted")
        } else {
            Text(text = "Set an interval below, then start your day")
        }

        Spacer(modifier = Modifier.height(24.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = intervalText,
                onValueChange = { newValue ->
                    if (newValue.length <= 4 && newValue.all { it.isDigit() }) {
                        intervalText = newValue
                    }
                },
                enabled = !isRunning,
                label = { Text("Minutes") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.width(120.dp)
            )
        }

        Spacer(modifier = Modifier.height(32.dp))

        Button(
            onClick = {
                if (isRunning) {
                    ReminderScheduler.stop(context)
                    isRunning = false
                    nextTriggerAt = 0L
                } else {
                    val minutes = intervalText.toIntOrNull()?.coerceAtLeast(1)
                        ?: DEFAULT_INTERVAL_MINUTES
                    intervalText = minutes.toString()
                    ReminderPrefs.setIntervalMinutes(context, minutes)

                    val alarmManager = context.getSystemService(AlarmManager::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                        !alarmManager.canScheduleExactAlarms()
                    ) {
                        showExactAlarmDialog = true
                    } else {
                        ReminderScheduler.start(context)
                        isRunning = true
                        nextTriggerAt = ReminderPrefs.nextTriggerAt(context)
                    }
                }
            }
        ) {
            Text(if (isRunning) "Stop for the night" else "Start my day")
        }
    }

    if (showExactAlarmDialog) {
        AlertDialog(
            onDismissRequest = { showExactAlarmDialog = false },
            title = { Text("Allow exact alarms") },
            text = {
                Text(
                    "Squat Reminder needs permission to schedule exact alarms " +
                        "so reminders land on time. Enable it in system settings, " +
                        "then tap Start again."
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showExactAlarmDialog = false
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                        data = Uri.parse("package:${context.packageName}")
                    }
                    context.startActivity(intent)
                }) {
                    Text("Open settings")
                }
            },
            dismissButton = {
                TextButton(onClick = { showExactAlarmDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}
